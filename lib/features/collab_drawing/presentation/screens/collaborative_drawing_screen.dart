import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../bloc/drawing_bloc.dart';
import '../../presentation/painters/strokes_painter.dart';
import '../../data/realtime/drawing_realtime_service.dart';

class CollaborativeDrawingScreen extends StatefulWidget {
  const CollaborativeDrawingScreen({super.key});

  @override
  State<CollaborativeDrawingScreen> createState() =>
      _CollaborativeDrawingScreenState();
}

class _CollaborativeDrawingScreenState
    extends State<CollaborativeDrawingScreen> {
  late final DrawingRealtimeService _realtime;

  // Throttle broadcast
  Timer? _throttleTimer;
  final Duration _throttleDuration = const Duration(milliseconds: 60);

  Size? _canvasSize;

  @override
  void initState() {
    super.initState();
    _realtime = DrawingRealtimeService();
    _realtime.subscribe(
      onStroke:
          (stroke) =>
              context.read<DrawingBloc>().add(RemoteStrokeEvent(stroke)),
      onClear: () => context.read<DrawingBloc>().add(RemoteClearEvent()),
      canvasSize: _canvasSize,
    );
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _realtime.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_canvasSize == null) return;
    final Offset local = details.localPosition;
    final bloc = context.read<DrawingBloc>();
    bloc.add(PanStartEvent(point: local));
    _broadcastThrottled();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_canvasSize == null) return;
    final Offset local = details.localPosition;
    final bloc = context.read<DrawingBloc>();
    bloc.add(PanUpdateEvent(point: local));
    _broadcastThrottled();
  }

  void _onPanEnd(DragEndDetails details) {
    context.read<DrawingBloc>().add(PanEndEvent());
    _broadcastNow();
  }

  void _broadcastThrottled() {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(_throttleDuration, _broadcastNow);
  }

  void _broadcastNow() {
    _throttleTimer?.cancel();
    final state = context.read<DrawingBloc>().state;
    final current = state.currentStroke;
    if (current == null || _canvasSize == null) return;
    _realtime.sendStroke(current, _canvasSize!);
  }

  void _clearCanvas() {
    context.read<DrawingBloc>().add(ClearEvent());
    _sendClearEverywhere();
  }

  Future<void> _sendClearEverywhere() async {
    _realtime.sendClear();
    await _realtime.bestEffortDeleteStrokesTable();
  }

  PopupMenuItem<Color> _colorItem(Color color, String label) {
    return PopupMenuItem<Color>(
      value: color,
      child: Row(
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawingBloc, DrawingState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Realtime Collaborative Drawing'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _clearCanvas,
                tooltip: 'Clear',
              ),
              PopupMenuButton<double>(
                initialValue: state.selectedWidth,
                itemBuilder:
                    (BuildContext context) => <PopupMenuEntry<double>>[
                      const PopupMenuItem<double>(
                        value: 2.0,
                        child: Text('Thin'),
                      ),
                      const PopupMenuItem<double>(
                        value: 4.0,
                        child: Text('Normal'),
                      ),
                      const PopupMenuItem<double>(
                        value: 8.0,
                        child: Text('Thick'),
                      ),
                    ],
                onSelected:
                    (double v) =>
                        context.read<DrawingBloc>().add(SelectWidthEvent(v)),
                icon: const Icon(Icons.brush),
                tooltip: 'Stroke width',
              ),
              PopupMenuButton<Color>(
                initialValue: state.selectedColor,
                itemBuilder:
                    (BuildContext context) => <PopupMenuEntry<Color>>[
                      _colorItem(Colors.black, 'Black'),
                      _colorItem(Colors.blue, 'Blue'),
                      _colorItem(Colors.red, 'Red'),
                      _colorItem(Colors.green, 'Green'),
                      _colorItem(Colors.purple, 'Purple'),
                    ],
                onSelected:
                    (Color c) =>
                        context.read<DrawingBloc>().add(SelectColorEvent(c)),
                icon: const Icon(Icons.color_lens_outlined),
                tooltip: 'Color',
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: StrokesPainter(state.strokes),
                  size: Size.infinite,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
