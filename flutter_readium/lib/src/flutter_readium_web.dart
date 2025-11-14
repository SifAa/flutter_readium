import 'dart:async';
import 'dart:convert';
import 'package:flutter_readium_platform_interface/flutter_readium_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'js_publication_channel.dart';
import 'package:flutter/services.dart';

class FlutterReadiumWebPlugin extends FlutterReadiumPlatform {
  static void registerWith(Registrar registrar) {
    FlutterReadiumPlatform.instance = FlutterReadiumWebPlugin();
  }

  static final StreamController<Locator> _locatorTextController = StreamController<Locator>.broadcast();
  static final StreamController<Locator> _locatorAudioController = StreamController<Locator>.broadcast();
  static final StreamController<ReadiumReaderStatus> _readerStatusController =
      StreamController<ReadiumReaderStatus>.broadcast();

  static void addTextLocatorUpdate(Locator locator) {
    _locatorTextController.add(locator);
  }

  static void addAudioLocatorUpdate(Locator locator) {
    _locatorAudioController.add(locator);
  }

  static void addReaderStatusUpdate(ReadiumReaderStatus status) {
    _readerStatusController.add(status);
  }

  @override
  Stream<Locator> get onTextLocatorChanged {
    return _locatorTextController.stream;
  }

  @override
  Stream<Locator> get onAudioLocatorChanged {
    return _locatorAudioController.stream;
  }

  @override
  Stream<ReadiumReaderStatus> get onReaderStatusChanged {
    return _readerStatusController.stream;
  }

  @override
  Future<void> setCustomHeaders(Map<String, String> headers) =>
      throw UnimplementedError('setCustomHeaders is not implemented on web platform');

  @override
  void setDefaultPreferences(EPUBPreferences preferences) {
    defaultPreferences = preferences;
  }

  @override
  Future<Publication> loadPublication(String pubUrl) async {
    Publication publication;

    try {
      final publicationString = await JsPublicationChannel().getPublication(pubUrl);

      var publicationJson = jsonDecode(publicationString) as Map<String, dynamic>;

      publicationJson = _transformPublicationJson(publicationJson);

      publication = Publication.fromJson(publicationJson);
    } on PlatformException catch (e) {
      final type = e.intCode;
      throw OpeningReadiumException(
        '${e.code}: ${e.message ?? 'Unknown `PlatformException`'}',
        type: type == null ? null : OpeningReadiumExceptionType.values[type],
      );
    } on Error catch (e) {
      final eString = e.toString();
      throw ReadiumError('Error in PublicationChannel web $pubUrl: $eString');
    } on Exception catch (e) {
      final eString = e.toString();
      throw ReadiumError('Exception in PublicationChannel web $pubUrl: $eString');
    }

    return publication;
  }

  static Map<String, dynamic> _transformPublicationJson(
    final Map<String, dynamic> publicationJson,
  ) {
    // TODO: create issue in ts-toolkit and remove this workaround when fixed
    if (publicationJson.containsKey('metadata') && publicationJson['metadata'] is Map) {
      final metadataMap = publicationJson['metadata'] as Map<String, dynamic>;

      _replaceUndefinedKey(metadataMap);

      if (metadataMap.containsKey('sortAs')) {
        final sortAs = metadataMap['sortAs'];
        if (sortAs is Map) {
          if (sortAs.isNotEmpty) {
            // Use the first value in the translations map
            metadataMap['sortAs'] = sortAs.values.first;
            R2Log.d('Pub: ${metadataMap['title']} sortAs map transformed to first value.');
          } else {
            metadataMap['sortAs'] = null;
            R2Log.d('Pub: ${metadataMap['title']} sortAs map is empty, setting to null.');
          }
        } else if (sortAs is! String) {
          metadataMap['sortAs'] = null;
          R2Log.d(
              'Pub: ${metadataMap['title']} sortAs is not a String or Map, setting to null. Actual type: ${sortAs.runtimeType}');
        }
      }
    }

    return publicationJson;
  }

  static void _replaceUndefinedKey(Map<dynamic, dynamic> map) {
    final keysToReplace = <dynamic>[];
    map.forEach((key, value) {
      if (key == 'undefined') {
        keysToReplace.add(key);
      }
      if (value is Map) {
        _replaceUndefinedKey(value);
      } else if (value is List) {
        for (var item in value) {
          if (item is Map) {
            _replaceUndefinedKey(item);
          }
        }
      }
    });
    for (var key in keysToReplace) {
      map['und'] = map.remove(key);
    }
  }

  @override
  Future<Publication> openPublication(String pubUrl) async {
    // NOTE: For web, loadPublication and openPublication does the same thing,
    //
    // If calling the openPublication method outside of ReadiumWebView it will throw an error right away if there is no div with the id 'container'
    // additionally the openPublication method does currently not return a publication object
    R2Log.d(
        'Cannot call openPublication outside of ReadiumWebView on web. Using getPublication instead to fetch the publication data.');
    final publication = await loadPublication(pubUrl);
    return publication;
  }

  @override
  Future<void> closePublication() async {
    JsPublicationChannel().closePublication();
    return;
  }

  @override
  Future<String?> getLinkContent(Link link) {
    return getString(link);
  }

  static Future<String> getString(final Link link) async {
    // Get HTML string for full chapters, for example
    final linkString = json.encode(link);
    final resourceString = await JsPublicationChannel().getResource(linkString);
    return resourceString;
  }

  static Future<Uint8List> getBytes(final Link link) async {
    // TODO: Is this still needed for audio books with the new implementation
    final linkString = json.encode(link);
    final resourceBytesString = await JsPublicationChannel().getResource(linkString, asBytes: true);
    final byteList = jsonDecode(resourceBytesString).cast<int>();
    return Uint8List.fromList(byteList);
  }

  @override
  Future<void> goLeft({final bool animated = true}) async {
    JsPublicationChannel.goLeft();
  }

  @override
  Future<void> goRight({final bool animated = true}) async {
    JsPublicationChannel.goRight();
  }

  @override
  Future<void> skipToNext() async {
    R2Log.d('skipToNext is not implemented on web platform');
  }

  @override
  Future<void> skipToPrevious() async {
    R2Log.d('skipToPrevious is not implemented on web platform');
  }

  @override
  Future<void> setEPUBPreferences(EPUBPreferences preferences) async {
    defaultPreferences = preferences;
    JsPublicationChannel().setEPUBPreferences(json.encode(preferences.toJson()));
  }

  @override
  Future<void> applyDecorations(String id, List<ReaderDecoration> decorations) async {
    R2Log.d('applyDecorations is not implemented on web platform');
  }

  // COMMON PLAYBACK API - BEGIN
  @override
  Future<void> play(Locator? fromLocator) => throw UnimplementedError('play is not implemented on web platform');

  @override
  Future<void> stop() => throw UnimplementedError('stop is not implemented on web platform');

  @override
  Future<void> pause() => throw UnimplementedError('pause is not implemented on web platform');

  @override
  Future<void> resume() => throw UnimplementedError('resume is not implemented on web platform');

  @override
  Future<void> next() => throw UnimplementedError('next is not implemented on web platform');

  @override
  Future<void> previous() => throw UnimplementedError('previous is not implemented on web platform');

  @override
  Future<bool> goToLocator(final Locator locator) async {
    try {
      await JsPublicationChannel.goToLocation(locator.hrefPath);
      return true;
    } on PlatformException catch (e, stackTrace) {
      final pubID = 'unknown';
      throw ReadiumError(
        'Error when navigating to locator: ${e.message}',
        code: e.code,
        data: 'publication id: $pubID. locator: $locator',
        stackTrace: stackTrace,
      );
    }
  }
  // COMMON PLAYBACK API - END

  // TTS API - BEGIN
  @override
  Future<void> ttsEnable(TTSPreferences? preferences) async {
    R2Log.d('ttsEnable is not implemented on web platform');
  }

  @override
  Future<List<ReaderTTSVoice>> ttsGetAvailableVoices() async {
    R2Log.d('ttsGetAvailableVoices is not implemented on web platform');
    return [];
  }

  @override
  Future<void> ttsSetVoice(String voiceIdentifier, String? forLanguage) async {
    R2Log.d('ttsSetVoice is not implemented on web platform');
  }

  @override
  Future<void> setDecorationStyle(
    ReaderDecorationStyle? utteranceDecoration,
    ReaderDecorationStyle? rangeDecoration,
  ) async {
    R2Log.d('setDecorationStyle is not implemented on web platform');
  }

  @override
  Future<void> ttsSetPreferences(TTSPreferences preferences) async {
    R2Log.d('ttsSetPreferences is not implemented on web platform');
  }
  // TTS API - END

  // AUDIOBOOK API - BEGIN
  @override
  Future<void> audioEnable({AudioPreferences? prefs, Locator? fromLocator}) =>
      throw UnimplementedError('audioEnable is not implemented on web platform');

  @override
  Future<void> audioSetPreferences(AudioPreferences prefs) =>
      throw UnimplementedError('audioSetPreferences is not implemented on web platform');
  // AUDIOBOOK API - END

  @override
  Stream<ReadiumTimebasedState> get onTimebasedPlayerStateChanged {
    // TODO: Implement when karaoke books are supported
    // throw UnimplementedError('get onTimebasedPlayerStateChanged is not implemented on web platform');
    return const Stream.empty();
  }

  @override
  Stream<ReadiumError> get onErrorEvent {
    throw UnimplementedError('get onErrorEvent is not implemented on web platform');
  }
}
