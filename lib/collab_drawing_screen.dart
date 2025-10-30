import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/drawing_bloc.dart';

class CollaborativeDrawingScreen extends StatefulWidget {
  const CollaborativeDrawingScreen({super.key});

  @override
  State<CollaborativeDrawingScreen> createState() =>
      _CollaborativeDrawingScreenState();
}

class _CollaborativeDrawingScreenState
    extends State<CollaborativeDrawingScreen> {
  // We keep networking here but state is managed by DrawingBloc
  late final RealtimeChannel _channel;
  final String _clientId = const Uuid().v4();

  // Throttle broadcast
  Timer? _throttleTimer;
  final Duration _throttleDuration = const Duration(milliseconds: 60);

  Size? _canvasSize;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('room:draw');

    _channel.onBroadcast(
      event: 'stroke',
      callback: (dynamic payload, [String? ref]) {
        if (payload is! Map) return;
        final senderId = payload['senderId'] as String?;
        if (senderId == _clientId) return; // Ignore own events

        final colorVal = payload['color'] as int? ?? Colors.blue.value;
        final width = (payload['width'] as num?)?.toDouble() ?? 4.0;
        final List<dynamic> points =
            (payload['points'] as List<dynamic>? ?? <dynamic>[]);
        final List<Offset> decoded = <Offset>[];
        final double w = (_canvasSize?.width ?? 1).toDouble();
        final double h = (_canvasSize?.height ?? 1).toDouble();
        for (final dynamic p in points) {
          if (p is Map) {
            final dx = (p['x'] as num).toDouble() * w;
            final dy = (p['y'] as num).toDouble() * h;
            decoded.add(Offset(dx, dy));
          }
        }
        if (decoded.isEmpty) return;
        // dispatch to bloc
        final stroke = Stroke(
          color: Color(colorVal),
          width: width,
          points: decoded,
        );
        context.read<DrawingBloc>().add(RemoteStrokeEvent(stroke));
      },
    );

    _channel.onBroadcast(
      event: 'clear',
      callback: (dynamic payload, [String? ref]) {
        // If we ever need to ignore own clear, we can check senderId here.
        context.read<DrawingBloc>().add(RemoteClearEvent());
      },
    );

    _channel.subscribe();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _channel.unsubscribe();
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
    final payload = _encodeStroke(current, _canvasSize!);
    _channel.sendBroadcastMessage(event: 'stroke', payload: payload);
  }

  Map<String, dynamic> _encodeStroke(Stroke stroke, Size size) {
    final double w = max(1, size.width);
    final double h = max(1, size.height);
    return <String, dynamic>{
      'senderId': _clientId,
      'color': stroke.color.value,
      'width': stroke.width,
      'points':
          stroke.points
              .map((Offset o) => <String, double>{'x': o.dx / w, 'y': o.dy / h})
              .toList(),
    };
  }

  void _clearCanvas() {
    context.read<DrawingBloc>().add(ClearEvent());
    _sendClearEverywhere();
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
                  painter: _StrokesPainter(state.strokes),
                  size: Size.infinite,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _sendClearEverywhere() async {
    // Notify other clients
    _channel.sendBroadcastMessage(
      event: 'clear',
      payload: <String, dynamic>{'senderId': _clientId},
    );

    // Best-effort DB wipe if a strokes table exists; ignore if not configured
    try {
      await Supabase.instance.client.from('strokes').delete();
    } catch (_) {
      // No-op if table doesn't exist or delete is not permitted
    }
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
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final Stroke stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint =
          Paint()
            ..color = stroke.color
            ..strokeWidth = stroke.width
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true;

      final path =
          Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
