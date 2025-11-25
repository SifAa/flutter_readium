  interface Window {
    /**
     * Inform the Flutter app of the current reader status
     * @param status
     * @returns
     */
    updateReaderStatus?: (status: ReadiumReaderStatus) => void;

    /**
     * Update the current text locator in the Flutter app
     * @param locatorJson JSON stringified Locator
     * @returns
     */
    updateTextLocator?: (locatorJson: string) => void;
  }
