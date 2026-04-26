import 'package:flutter/material.dart';

class AnimatedFileItem extends StatefulWidget {
  final String name;
  final String type;
  final VoidCallback onTap;
  final IconData? customIcon;

  const AnimatedFileItem({
    super.key,
    required this.name,
    required this.type,
    required this.onTap,
    this.customIcon,
  });

  @override
  State<AnimatedFileItem> createState() => _AnimatedFileItemState();
}

class _AnimatedFileItemState extends State<AnimatedFileItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.blue.withOpacity(0.1),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: _colorAnimation.value,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _colorAnimation.value != Colors.transparent
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getIconColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.customIcon ?? _getIcon(),
                  color: _getIconColor(),
                  size: 24,
                ),
              ),
              title: Text(
                widget.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              trailing: AnimatedRotation(
                turns: _animationController.status == AnimationStatus.forward
                    ? 0.25
                    : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ),
              onTap: () {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                });
                widget.onTap();
              },
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon() {
    switch (widget.type.toLowerCase()) {
      case 'folder':
        return Icons.folder;
      case 'document':
      case 'documents':
        return Icons.description;
      case 'download':
      case 'downloads':
        return Icons.download;
      case 'picture':
      case 'pictures':
        return Icons.image;
      case 'video':
      case 'videos':
        return Icons.videocam;
      case 'music':
        return Icons.music_note;
      case 'network':
        return Icons.wifi;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor() {
    switch (widget.type.toLowerCase()) {
      case 'folder':
        return Colors.blue;
      case 'document':
      case 'documents':
        return Colors.indigo;
      case 'download':
      case 'downloads':
        return Colors.green;
      case 'picture':
      case 'pictures':
        return Colors.purple;
      case 'video':
      case 'videos':
        return Colors.red;
      case 'music':
        return Colors.orange;
      case 'network':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
