import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Events
abstract class DrawingEvent {}

class PanStartEvent extends DrawingEvent {
  PanStartEvent({required this.point, this.color, this.width});
  final Offset point;
  final Color? color;
  final double? width;
}

class PanUpdateEvent extends DrawingEvent {
  PanUpdateEvent({required this.point});
  final Offset point;
}

class PanEndEvent extends DrawingEvent {}

class SelectColorEvent extends DrawingEvent {
  SelectColorEvent(this.color);
  final Color color;
}

class SelectWidthEvent extends DrawingEvent {
  SelectWidthEvent(this.width);
  final double width;
}

class RemoteStrokeEvent extends DrawingEvent {
  RemoteStrokeEvent(this.stroke);
  final Stroke stroke;
}

class ClearEvent extends DrawingEvent {}

class RemoteClearEvent extends DrawingEvent {}

/// Stroke model
class Stroke extends Equatable {
  const Stroke({
    required this.color,
    required this.width,
    required this.points,
  });
  final Color color;
  final double width;
  final List<Offset> points;

  Stroke copyWith({Color? color, double? width, List<Offset>? points}) {
    return Stroke(
      color: color ?? this.color,
      width: width ?? this.width,
      points: points ?? this.points,
    );
  }

  @override
  List<Object?> get props => [color.value, width, points.length];
}

/// State
class DrawingState extends Equatable {
  const DrawingState({
    required this.strokes,
    this.currentStroke,
    required this.selectedColor,
    required this.selectedWidth,
    this.lastAction,
  });
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final Color selectedColor;
  final double selectedWidth;
  final String? lastAction;

  factory DrawingState.initial() {
    return DrawingState(
      strokes: <Stroke>[],
      currentStroke: null,
      selectedColor: Colors.blue,
      selectedWidth: 4.0,
      lastAction: null,
    );
  }

  DrawingState copyWith({
    List<Stroke>? strokes,
    Stroke? currentStroke,
    Color? selectedColor,
    double? selectedWidth,
    String? lastAction,
  }) {
    return DrawingState(
      strokes: strokes ?? this.strokes,
      currentStroke: currentStroke,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedWidth: selectedWidth ?? this.selectedWidth,
      lastAction: lastAction,
    );
  }

  @override
  List<Object?> get props => [
    strokes.length,
    currentStroke?.points.length ?? 0,
    selectedColor.value,
    selectedWidth,
    lastAction,
  ];
}

/// Bloc
class DrawingBloc extends Bloc<DrawingEvent, DrawingState> {
  DrawingBloc() : super(DrawingState.initial()) {
    on<PanStartEvent>(_onPanStart);
    on<PanUpdateEvent>(_onPanUpdate);
    on<PanEndEvent>(_onPanEnd);
    on<SelectColorEvent>(_onSelectColor);
    on<SelectWidthEvent>(_onSelectWidth);
    on<RemoteStrokeEvent>(_onRemoteStroke);
    on<ClearEvent>(_onClear);
    on<RemoteClearEvent>(_onRemoteClear);
  }

  void _onPanStart(PanStartEvent evt, Emitter<DrawingState> emit) {
    final stroke = Stroke(
      color: evt.color ?? state.selectedColor,
      width: evt.width ?? state.selectedWidth,
      points: <Offset>[evt.point],
    );
    final List<Stroke> newStrokes = List<Stroke>.from(state.strokes)
      ..add(stroke);
    emit(
      state.copyWith(
        strokes: newStrokes,
        currentStroke: stroke,
        lastAction: 'pan_start',
      ),
    );
  }

  void _onPanUpdate(PanUpdateEvent evt, Emitter<DrawingState> emit) {
    if (state.currentStroke == null) return;
    final Stroke updated = state.currentStroke!.copyWith(
      points: List<Offset>.from(state.currentStroke!.points)..add(evt.point),
    );
    final List<Stroke> newStrokes = List<Stroke>.from(state.strokes);
    if (newStrokes.isNotEmpty) {
      newStrokes[newStrokes.length - 1] = updated;
    } else {
      newStrokes.add(updated);
    }
    emit(
      state.copyWith(
        strokes: newStrokes,
        currentStroke: updated,
        lastAction: 'pan_update',
      ),
    );
  }

  void _onPanEnd(PanEndEvent evt, Emitter<DrawingState> emit) {
    emit(state.copyWith(currentStroke: null, lastAction: 'pan_end'));
  }

  void _onSelectColor(SelectColorEvent evt, Emitter<DrawingState> emit) {
    emit(state.copyWith(selectedColor: evt.color, lastAction: 'select_color'));
  }

  void _onSelectWidth(SelectWidthEvent evt, Emitter<DrawingState> emit) {
    emit(state.copyWith(selectedWidth: evt.width, lastAction: 'select_width'));
  }

  void _onRemoteStroke(RemoteStrokeEvent evt, Emitter<DrawingState> emit) {
    final List<Stroke> newStrokes = List<Stroke>.from(state.strokes)
      ..add(evt.stroke);
    emit(state.copyWith(strokes: newStrokes, lastAction: 'remote_stroke'));
  }

  void _onClear(ClearEvent evt, Emitter<DrawingState> emit) {
    emit(
      state.copyWith(
        strokes: <Stroke>[],
        currentStroke: null,
        lastAction: 'clear',
      ),
    );
  }

  void _onRemoteClear(RemoteClearEvent evt, Emitter<DrawingState> emit) {
    emit(
      state.copyWith(
        strokes: <Stroke>[],
        currentStroke: null,
        lastAction: 'remote_clear',
      ),
    );
  }
}
