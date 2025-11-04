import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/barrage_input_widget.dart';
import '../widgets/barrage_display_widget.dart';
import '../services/barrage_service.dart';

/// Demo screen to test the complete barrage message system
/// 
/// This screen demonstrates both the input and display components
/// working together with Firebase Firestore integration.
class BarrageDemoScreen extends StatefulWidget {
  const BarrageDemoScreen({super.key});

  @override
  State<BarrageDemoScreen> createState() => _BarrageDemoScreenState();
}

class _BarrageDemoScreenState extends State<BarrageDemoScreen> {
  bool _isBarrageActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('弹幕系统演示'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isBarrageActive = !_isBarrageActive;
              });
            },
            icon: Icon(_isBarrageActive ? Icons.pause : Icons.play_arrow),
            tooltip: _isBarrageActive ? '暂停弹幕' : '开启弹幕',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Main content area
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '🎉 宝宝性别揭晓派对 🎉',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '发送祝福弹幕庆祝这个特殊时刻！',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '弹幕系统功能:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• 实时祝福消息\n• 传统中式设计\n• 多轨道动画\n• 烟花特效\n• 主持人控制',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isBarrageActive ? Icons.play_circle : Icons.pause_circle,
                              color: _isBarrageActive ? Colors.green : Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isBarrageActive ? '弹幕已开启' : '弹幕已暂停',
                              style: TextStyle(
                                fontSize: 16,
                                color: _isBarrageActive ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Barrage input widget (bottom-right floating button)
            BarrageInputWidget(
              onMessageSend: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('祝福已发送: $message'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),

            // Barrage display system (full-screen overlay)
            StreamBuilder<QuerySnapshot>(
              stream: BarrageService.getMessageStream(),
              builder: (context, snapshot) {
                if (snapshot.hasData && _isBarrageActive) {
                  return BarrageDisplayWidget(
                    isActive: _isBarrageActive,
                    messages: snapshot.data!.docs,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Usage instructions widget
class BarrageUsageInstructions extends StatelessWidget {
  const BarrageUsageInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '弹幕系统使用说明',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            '1. 点击右下角画笔图标',
            '展开祝福输入界面',
            Icons.brush,
          ),
          _buildInstructionItem(
            '2. 输入祝福或选择预设',
            '最多20个字符的祝福消息',
            Icons.edit,
          ),
          _buildInstructionItem(
            '3. 点击发送按钮',
            '祝福将在大屏幕上飞过',
            Icons.send,
          ),
          _buildInstructionItem(
            '4. 查看最近消息',
            '在输入框上方看到其他人的祝福',
            Icons.history,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '提示: 预设的祝福消息包含表情符号，让祝福更生动有趣！',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
