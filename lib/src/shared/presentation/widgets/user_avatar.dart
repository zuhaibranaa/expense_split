import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            if (avatarUrl != null) {
              showImageView(context, avatarUrl!, name);
            }
          },
      child: Hero(
        tag: 'avatar_${avatarUrl ?? name}',
        child: CircleAvatar(
          radius: radius,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: radius),
                )
              : null,
        ),
      ),
    );
  }

  static void showImageView(
    BuildContext context,
    String avatarUrl,
    String name,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (BuildContext context, animation, secondaryAnimation) {
          return _ZoomableAvatarView(avatarUrl: avatarUrl, name: name);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _ZoomableAvatarView extends StatefulWidget {
  final String avatarUrl;
  final String name;

  const _ZoomableAvatarView({required this.avatarUrl, required this.name});

  @override
  State<_ZoomableAvatarView> createState() => _ZoomableAvatarViewState();
}

class _ZoomableAvatarViewState extends State<_ZoomableAvatarView> {
  final TransformationController _transformationController =
      TransformationController();
  double _scale = 1.0;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChange);
  }

  void _onTransformationChange() {
    final double currentScale = _transformationController.value
        .getMaxScaleOnAxis();
    if (currentScale != _scale) {
      if (mounted) {
        setState(() {
          _scale = currentScale;
        });
      }
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChange);
    _transformationController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final double distance = _dragOffset.dy.abs();
    final double threshold = MediaQuery.of(context).size.height * 0.15;

    if (distance > threshold || velocity.abs() > 1000) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = Offset.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only enable panning in InteractiveViewer if we are zoomed in
    final bool isZoomed = _scale > 1.01;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double dragRatio = (_dragOffset.dy.abs() / (screenHeight / 2)).clamp(
      0.0,
      1.0,
    );

    final double opacity = (1.0 - dragRatio).clamp(0.0, 1.0);
    final double displayScale = 1.0 - (dragRatio * 0.2);
    final double borderRadius = dragRatio * 100.0; // Animate to circle-ish

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: opacity)),
          ),
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragUpdate: isZoomed ? null : _onVerticalDragUpdate,
              onVerticalDragEnd: isZoomed ? null : _onVerticalDragEnd,
              child: Transform.translate(
                offset: _dragOffset,
                child: Transform.scale(
                  scale: displayScale,
                  child: Center(
                    child: Hero(
                      tag: 'avatar_${widget.avatarUrl}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          panEnabled: isZoomed,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.network(
                            widget.avatarUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Opacity(
                opacity: opacity,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
