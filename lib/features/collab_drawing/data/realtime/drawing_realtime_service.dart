import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../bloc/drawing_bloc.dart';

typedef StrokeHandler = void Function(Stroke stroke);
typedef VoidHandler = void Function();

class DrawingRealtimeService {
  DrawingRealtimeService({String channelName = 'room:draw'})
      : _client = Supabase.instance.client,
        _channelName = channelName,
        _clientId = const Uuid().v4();

  final SupabaseClient _client;
  final String _channelName;
  final String _clientId;

  late final RealtimeChannel _channel = _client.channel(_channelName);

  void subscribe({required StrokeHandler onStroke, required VoidHandler onClear, Size? canvasSize}) {
    _channel.onBroadcast(
      event: 'stroke',
      callback: (dynamic payload, [String? ref]) {
        if (payload is! Map) return;
        final senderId = payload['senderId'] as String?;
        if (senderId == _clientId) return;

        final colorVal = payload['color'] as int? ?? Colors.blue.value;
        final width = (payload['width'] as num?)?.toDouble() ?? 4.0;
        final List<dynamic> points = (payload['points'] as List<dynamic>? ?? <dynamic>[]);
        final List<Offset> decoded = <Offset>[];
        final double w = (canvasSize?.width ?? 1).toDouble();
        final double h = (canvasSize?.height ?? 1).toDouble();
        for (final dynamic p in points) {
          if (p is Map) {
            final dx = (p['x'] as num).toDouble() * w;
            final dy = (p['y'] as num).toDouble() * h;
            decoded.add(Offset(dx, dy));
          }
        }
        if (decoded.isEmpty) return;
        onStroke(
          Stroke(
            color: Color(colorVal),
            width: width,
            points: decoded,
          ),
        );
      },
    );

    _channel.onBroadcast(
      event: 'clear',
      callback: (dynamic payload, [String? ref]) => onClear(),
    );

    _channel.subscribe();
  }

  void dispose() {
    _channel.unsubscribe();
  }

  void sendStroke(Stroke stroke, Size size) {
    final payload = _encodeStroke(stroke, size);
    _channel.sendBroadcastMessage(event: 'stroke', payload: payload);
  }

  void sendClear() {
    _channel.sendBroadcastMessage(
      event: 'clear',
      payload: <String, dynamic>{'senderId': _clientId},
    );
  }

  Map<String, dynamic> _encodeStroke(Stroke stroke, Size size) {
    final double w = max(1, size.width);
    final double h = max(1, size.height);
    return <String, dynamic>{
      'senderId': _clientId,
      'color': stroke.color.value,
      'width': stroke.width,
      'points': stroke.points
          .map((Offset o) => <String, double>{'x': o.dx / w, 'y': o.dy / h})
          .toList(),
    };
  }

  Future<void> bestEffortDeleteStrokesTable() async {
    try {
      await _client.from('strokes').delete();
    } catch (_) {
      // ignore
    }
  }
}


