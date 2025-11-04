import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/barrage_service.dart';
import '../services/auth_service.dart';

/// Input widget for guests to send barrage messages during the gender reveal party
/// 
/// Features:
/// - Floating action button that expands to input form
/// - Traditional Chinese scroll design
/// - Pre-written blessing buttons
/// - Character limit and validation
/// - Recent messages preview
/// - Smooth animations and ink splash effects
class BarrageInputWidget extends StatefulWidget {
  /// Callback function when a message is sent
  final Function(String) onMessageSend;
  
  const BarrageInputWidget({
    super.key,
    required this.onMessageSend,
  });

  @override
  State<BarrageInputWidget> createState() => _BarrageInputWidgetState();
}

class _BarrageInputWidgetState extends State<BarrageInputWidget>
    with TickerProviderStateMixin {
  
  /// Animation controllers
  late AnimationController _expandController;
  late AnimationController _fadeController;
  late AnimationController _inkController;
  
  /// Animations
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _inkAnimation;
  
  /// Form controllers
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  /// State management
  bool _isExpanded = false;
  bool _isSending = false;
  int _characterCount = 0;
  
  /// Pre-written blessing messages
  final List<String> _blessings = [
    '恭喜恭喜! 🎉',
    '祝宝宝健康! 👶',
    '欢迎小宝贝! 💕',
    '好幸福呀! ✨',
    '祝福满满! 🌟',
    '可爱宝贝! 🎈',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupControllers();
  }

  void _initializeAnimations() {
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _inkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _expandAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _inkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _inkController,
      curve: Curves.easeOut,
    ));
  }

  void _setupControllers() {
    _messageController.addListener(() {
      setState(() {
        _characterCount = _messageController.text.length;
      });
    });
  }

  /// Toggle the expansion state of the input widget
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _expandController.forward();
      _fadeController.forward();
    } else {
      _expandController.reverse();
      _fadeController.reverse();
      _focusNode.unfocus();
    }
  }

  /// Send a message (either custom or pre-written)
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || message.length > 20) return;

    setState(() {
      _isSending = true;
    });

    // Trigger ink splash animation
    _inkController.forward().then((_) {
      _inkController.reverse();
    });

    try {
      // Get the current user's display name
      final currentUser = AuthService.currentUser;
      final username = AuthService.getUserDisplayName(currentUser);
      
      await BarrageService.sendMessage(message, sender: username);
      widget.onMessageSend(message);
      
      // Clear input and collapse
      _messageController.clear();
      _toggleExpansion();
      
      // Show success feedback
      HapticFeedback.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('消息已发送: $message'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _fadeController.dispose();
    _inkController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 16,
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Recent messages preview (when expanded)
              if (_isExpanded) _buildRecentMessagesPreview(),
              
              // Main input area (when expanded)
              if (_isExpanded) _buildInputArea(),
              
              const SizedBox(height: 16),
              
              // Floating action button
              _buildFloatingActionButton(),
            ],
          );
        },
      ),
    );
  }

  /// Build the recent messages preview scroll area
  Widget _buildRecentMessagesPreview() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: 280,
        height: 80,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber, width: 2),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: BarrageService.getRecentMessagesStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Text(
                  '暂无消息',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              );
            }

            final messages = snapshot.data!.docs;
            
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    message['barrage_message'],
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontFamily: 'serif',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Build the main input area with traditional Chinese scroll design
  Widget _buildInputArea() {
    return ScaleTransition(
      scale: _expandAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8DC), // Cornsilk
                Color(0xFFF5DEB3), // Wheat
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB8860B), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Traditional header
              _buildScrollHeader(),
              
              const SizedBox(height: 12),
              
              // Input field
              _buildInputField(),
              
              const SizedBox(height: 12),
              
              // Pre-written blessings
              _buildBlessingsGrid(),
              
              const SizedBox(height: 12),
              
              // Send button
              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build traditional Chinese scroll header
  Widget _buildScrollHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFB8860B), width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📜', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text(
            '祝福弹幕',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB8860B),
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(width: 8),
          const Text('📜', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  /// Build the text input field with character counter
  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD), width: 1),
      ),
      child: TextField(
        controller: _messageController,
        focusNode: _focusNode,
        maxLength: 20,
        decoration: InputDecoration(
          hintText: '写下你的祝福...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
          counterText: '$_characterCount/20',
          counterStyle: TextStyle(
            color: _characterCount > 15 ? Colors.red : Colors.grey[600],
            fontSize: 11,
          ),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// Build the pre-written blessings grid
  Widget _buildBlessingsGrid() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _blessings.map((blessing) {
        return InkWell(
          onTap: () => _sendMessage(blessing),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB8860B), width: 1),
            ),
            child: Text(
              blessing,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B4513),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Build the send button with ink splash animation
  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _inkAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Main send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending || _messageController.text.trim().isEmpty
                    ? null
                    : () => _sendMessage(_messageController.text),
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(_isSending ? '发送中...' : '发送祝福'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC143C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            
            // Ink splash overlay
            if (_inkAnimation.value > 0)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.3 * (1 - _inkAnimation.value),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build the floating action button
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _toggleExpansion,
      backgroundColor: _isExpanded ? Colors.red[400] : const Color(0xFFDC143C),
      child: AnimatedRotation(
        turns: _isExpanded ? 0.25 : 0,
        duration: const Duration(milliseconds: 300),
        child: Icon(
          _isExpanded ? Icons.close : Icons.brush,
          color: Colors.white,
        ),
      ),
    );
  }
}
