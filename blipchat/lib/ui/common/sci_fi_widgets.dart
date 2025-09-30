import 'package:flutter/material.dart';
import 'package:blipchat/ui/common/app_colors.dart';

class NeonContainer extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double glowIntensity;

  const NeonContainer({
    Key? key,
    required this.child,
    this.glowColor,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 12.0,
    this.glowIntensity = 8.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? kcNeonGlow;
    
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: effectiveGlowColor.withOpacity(0.3),
            blurRadius: glowIntensity,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: effectiveGlowColor.withOpacity(0.1),
            blurRadius: glowIntensity * 2,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(
            color: effectiveGlowColor.withOpacity(0.8),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kcGradientStart.withOpacity(0.8),
              kcGradientEnd.withOpacity(0.8),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class NeonToggleButton extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final Color? activeColor;
  final Color? inactiveColor;

  const NeonToggleButton({
    Key? key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.activeColor,
    this.inactiveColor,
  }) : super(key: key);

  @override
  State<NeonToggleButton> createState() => _NeonToggleButtonState();
}

class _NeonToggleButtonState extends State<NeonToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    if (widget.value) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(NeonToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? kcAccentColor;
    final inactiveColor = widget.inactiveColor ?? kcTextMuted;
    
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final color = Color.lerp(inactiveColor, activeColor, _animation.value)!;
          
          return NeonContainer(
            glowColor: widget.value ? activeColor : Colors.transparent,
            glowIntensity: widget.value ? 12.0 : 0.0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: widget.value ? [
                      BoxShadow(
                        color: color.withOpacity(0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ] : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SciFiTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSuffixPressed;
  final IconData? suffixIcon;
  final Color? glowColor;

  const SciFiTextField({
    Key? key,
    this.controller,
    this.hintText,
    this.onSubmitted,
    this.onSuffixPressed,
    this.suffixIcon,
    this.glowColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? kcPrimaryColor;
    
    return NeonContainer(
      glowColor: effectiveGlowColor,
      glowIntensity: 6.0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: kcTextLight,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: kcTextMuted.withOpacity(0.7),
            fontSize: 16,
          ),
          border: InputBorder.none,
          suffixIcon: onSuffixPressed != null ? 
            GestureDetector(
              onTap: onSuffixPressed,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  suffixIcon ?? Icons.send,
                  color: effectiveGlowColor,
                  size: 20,
                ),
              ),
            ) : null,
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String username;
  final String content;
  final DateTime timestamp;
  final bool isLocal;

  const MessageBubble({
    Key? key,
    required this.username,
    required this.content,
    required this.timestamp,
    required this.isLocal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final glowColor = isLocal ? kcPrimaryColor : kcSecondaryColor;
    final alignment = isLocal ? Alignment.centerRight : Alignment.centerLeft;
    
    return Container(
      alignment: alignment,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: NeonContainer(
          glowColor: glowColor,
          glowIntensity: 4.0,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      color: glowColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(timestamp),
                    style: const TextStyle(
                      color: kcTextMuted,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  color: kcTextLight,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
    }
  }
}

class SciFiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String username;
  final bool isConnected;
  final VoidCallback onToggleConnection;

  const SciFiAppBar({
    Key? key,
    required this.username,
    required this.isConnected,
    required this.onToggleConnection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kcGradientStart, kcGradientEnd],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'USER:',
                style: TextStyle(
                  color: kcTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                username,
                style: const TextStyle(
                  color: kcPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          NeonToggleButton(
            value: isConnected,
            onChanged: (value) => onToggleConnection(),
            label: isConnected ? 'ONLINE' : 'OFFLINE',
            activeColor: kcAccentColor,
            inactiveColor: kcErrorColor,
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(100);
}