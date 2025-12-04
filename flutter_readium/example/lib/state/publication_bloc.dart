import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

abstract class PublicationEvent {}

class ClosePublication extends PublicationEvent {}

class OpenPublication extends PublicationEvent {
  OpenPublication({
    required this.publicationUrl,
    this.initialLocator,
    this.autoPlay,
  });
  final String publicationUrl;
  final Locator? initialLocator;
  final bool? autoPlay;
}

class ReaderStatusChanged extends PublicationEvent {
  final ReadiumReaderStatus status;
  ReaderStatusChanged(this.status);
}

class PublicationState {
  PublicationState({
    this.publication,
    this.initialLocator,
    this.error,
    this.isLoading = false,
    this.readerStatus,
  });
  final Publication? publication;
  final Locator? initialLocator;
  final dynamic error;
  final bool isLoading;
  final ReadiumReaderStatus? readerStatus;

  PublicationState copyWith({
    final Publication? publication,
    final Locator? initialLocator,
    final dynamic error,
    final bool? isLoading,
    final ReadiumReaderStatus? readerStatus,
  }) =>
      PublicationState(
        publication: publication ?? this.publication,
        initialLocator: initialLocator ?? this.initialLocator,
        error: error ?? this.error,
        isLoading: isLoading ?? this.isLoading,
        readerStatus: readerStatus ?? this.readerStatus,
      );

  PublicationState openPublicationSuccess(final Publication publication, Locator? initialLocator) => PublicationState(
        publication: publication,
        initialLocator: initialLocator,
        isLoading: false,
        error: null,
        readerStatus: readerStatus,
      );

  PublicationState openPublicationFail(final dynamic error) =>
      copyWith(publication: publication, error: error, isLoading: false);

  PublicationState loading() => copyWith(isLoading: true);

  String errorDebugDescription() {
    if (error is ReadiumException) {
      ReadiumException re = error as ReadiumException;
      return '${re.type}: ${re.message}';
    } else {
      return error.toString();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'publication': publication?.toJson(),
      'initialLocator': initialLocator?.toJson(),
      'error': error?.toString(),
      'isLoading': isLoading,
      'readerStatus': readerStatus?.toString(),
    };
  }

  static PublicationState? fromJson(Map<String, dynamic> json) {
    return PublicationState(
      publication:
          json['publication'] != null ? Publication.fromJson(json['publication'] as Map<String, dynamic>) : null,
      initialLocator:
          json['initialLocator'] != null ? Locator.fromJson(json['initialLocator'] as Map<String, dynamic>) : null,
      error: json['error'],
      isLoading: json['isLoading'] ?? false,
      readerStatus: json['readerStatus'] != null
          ? ReadiumReaderStatus.values.firstWhereOrNull(
              (e) => e.toString() == json['readerStatus'],
            )
          : null,
    );
  }
}

class PublicationBloc extends HydratedBloc<PublicationEvent, PublicationState> {
  StreamSubscription<ReadiumReaderStatus>? _readerStatusSub;

  PublicationBloc() : super(PublicationState()) {
    // Listen to reader status changes and add event
    _readerStatusSub = FlutterReadium().onReaderStatusChanged.listen((status) {
      add(ReaderStatusChanged(status));
    });

    on<ReaderStatusChanged>((event, emit) {
      emit(state.copyWith(readerStatus: event.status));
    });

    on<OpenPublication>((final event, final emit) async {
      emit(state.loading());
      try {
        final instance = FlutterReadium();
        final publication = await instance.openPublication(event.publicationUrl);

        emit(state.openPublicationSuccess(publication, event.initialLocator));
      } on Exception catch (error) {
        emit(state.openPublicationFail(error));
      }
    });

    on<ClosePublication>((final event, final emit) async {
      try {
        await FlutterReadium().closePublication();

        // Wait for reader status to become closed
        await for (final status in FlutterReadium().onReaderStatusChanged) {
          if (status == ReadiumReaderStatus.closed) {
            break;
          }
        }
      } on Exception catch (error) {
        debugPrint('Exception while closing publication: ${error.toString()}');
      }
      emit(PublicationState());
    });
  }

  @override
  Future<void> close() {
    _readerStatusSub?.cancel();
    return super.close();
  }

  @override
  PublicationState? fromJson(Map<String, dynamic> json) {
    return PublicationState.fromJson(json);
  }

  @override
  Map<String, dynamic>? toJson(PublicationState state) {
    return state.toJson();
  }
}
