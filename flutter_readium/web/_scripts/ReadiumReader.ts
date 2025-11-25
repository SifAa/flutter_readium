import "./style.css";

import { EpubNavigator, WebPubNavigator } from "@readium/navigator";
import { Locator, Resource } from "@readium/shared";
import { Link } from "@readium/shared";

// Helpers and extensions
import { createPublicationJson, setPreferencesFromString } from "./helpers";
import { ReadiumReaderStatus } from "./enums";
import { ReadiumPublication } from "./extensions/ReadiumPublication";
import { initializeEpubNavigatorAndPeripherals } from "./Epub/epubNavigator";
import { initializeWebPubNavigatorAndPeripherals } from "./WebPub/webpubNavigator";

class _ReadiumReader {
  public constructor() {
    console.log("R2Navigator initialized");
  }

  private _publication: ReadiumPublication | undefined;
  private _nav: EpubNavigator | WebPubNavigator | undefined;

  public get isNavigatorReady(): boolean {
    return !!this._nav;
  }

  public async loadPublication(publicationURL: string) {
    try {
      const { manifestJson } = await createPublicationJson(publicationURL);
      return JSON.stringify(manifestJson);
    } catch (error) {
      throw new Error("Error loading publication: " + error);
    }
  }

  public async openPublication(publicationURL: string) {
    try {
      const { publication, manifestJson } = await createPublicationJson(
        publicationURL
      );
      this._publication = publication;
      return JSON.stringify(manifestJson);
    } catch (error) {
      throw new Error("Error setting publication: " + error);
    }
  }

  public goRight() {
    this._nav?.goRight(true, () => {});
  }

  public goLeft() {
    this._nav?.goLeft(true, () => {});
  }

  public async goTo(href: string): Promise<void> {
    let link = this._nav?.publication.resources?.findWithHref(href);
    if (!link) {
      let publicationLinks = this._nav?.publication.resources;
      let linksString = publicationLinks?.items
        .map((link) => link.href)
        .join(", ");
      let error = new Error(
        "Link not found " + href + ". Available links: " + linksString
      );
      throw error;
    }
    this._nav?.goLink(link, true, (ok) => {
      if (!ok) {
        let error = new Error("Failed to navigate to link " + href);
        throw error;
      }
    });
  }

  public async initializeNavigator(
    publicationURL: string,
    initialPositionJson: string | undefined,
    preferencesJson: string | undefined
  ) {
    window.updateReaderStatus?.(ReadiumReaderStatus.loading);
    const container: HTMLElement | null =
      document.body.querySelector("#container");

    if (!container) {
      this.closePublication("Container element not found");
      throw new Error("Container element not found");
    }

    let initialPosition: Locator | undefined;

    if (initialPositionJson) {
      initialPosition = Locator.deserialize(JSON.parse(initialPositionJson));
    }

    let preferencesJsonString =
      !preferencesJson || preferencesJson === "null" ? "{}" : preferencesJson;

    try {
      if (!this._publication) {
        console.log("Fetching publication for navigator initialization");
        const { publication } = await createPublicationJson(publicationURL);
        this._publication = publication;
      }

      if (this._publication.conformsToAudiobook) {
        // Initialize WebAudioEngine for audiobooks
        // TODO: wip
      } else {
        // Initialize EpubNavigator for ebooks
        if (this._publication.conformsToEpub) {
          await initializeEpubNavigatorAndPeripherals(
            container,
            this._publication,
            initialPosition,
            preferencesJsonString,
            (nav) => {
              this._nav = nav;
              window.updateReaderStatus?.(ReadiumReaderStatus.ready);
            }
          );
        } else {
          await initializeWebPubNavigatorAndPeripherals(
            container,
            this._publication,
            initialPosition,
            preferencesJsonString,
            (nav) => {
              this._nav = nav;
              window.updateReaderStatus?.(ReadiumReaderStatus.ready);
            }
          );
        }
      }
    } catch (error) {
      this.closePublication(error);
      throw new Error("Error opening publication: " + error);
    }
  }

  public setEPUBPreferences(newPreferencesString: string) {
    if (!this._nav) {
      throw new Error("Navigator is not initialized");
    }
    setPreferencesFromString(newPreferencesString, this._nav);
  }

  public closePublication(error?: any) {
    this._publication = undefined;
    this._nav?.destroy(); // Clean up the navigator instance
    this._nav = undefined;
    const container = document.getElementById("container");
    if (container) {
      container.innerHTML = ""; // Clear the container
    }
    if (error) {
      window.updateReaderStatus?.(ReadiumReaderStatus.error);
    } else {
      window.updateReaderStatus?.(ReadiumReaderStatus.closed);
    }

    delete window.updateTextLocator;
    delete window.updateReaderStatus;
  }

  public async getLinkContent(linkString: String, asBytes: boolean = false) {
    let linkJson = JSON.parse(linkString.toString());
    let link: Link | undefined = Link.deserialize(linkJson);
    if (!link) {
      console.error("Invalid link string");
    }
    let resourceLink: Resource | undefined = this._publication?.get(link!);

    if (!resourceLink) {
      console.error("Resource not found", link);
    }

    let linkContent: string | undefined;
    if (asBytes) {
      let resourceBytes = await resourceLink?.read();
      linkContent = JSON.stringify(Array.from(resourceBytes!));
    } else {
      linkContent = await resourceLink?.readAsString();
    }

    return linkContent;
  }
}

declare global {
  namespace globalThis {
    var ReadiumReader: typeof _ReadiumReader;
  }
}

globalThis.ReadiumReader = _ReadiumReader;
