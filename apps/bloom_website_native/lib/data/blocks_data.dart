class ApplicationBlock {
  final String id;
  final String title;
  final String category;
  final String description;
  final String flutterCode;

  const ApplicationBlock({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.flutterCode,
  });
}

const blocksData = <ApplicationBlock>[
  ApplicationBlock(
    id: 'dashboard-01',
    title: 'Analytics & Revenue Dashboard',
    category: 'Dashboard',
    description:
        'Production dashboard layout with revenue metrics, '
        'interactive area chart, recent transactions, and date '
        'filter.',
    flutterCode: r'''import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          BloomButton(
            size: BloomButtonSize.sm,
            variant: BloomButtonVariant.outline,
            leading: const Icon(Icons.download, size: 14),
            onPressed: () {},
            child: const Text('Download Report'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Metric Cards Row
            Row(
              children: [
                Expanded(
                  child: BloomCard(
                    header: const BloomCardHeader(
                      title: BloomCardTitle('Total Revenue'),
                      description: BloomCardDescription('+20.1% from last month'),
                    ),
                    content: const Text(
                      r'$45,231.89',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: BloomCard(
                    header: const BloomCardHeader(
                      title: BloomCardTitle('Active Subscriptions'),
                      description: BloomCardDescription('+180 new today'),
                    ),
                    content: const Text(
                      '+2,350',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Revenue Area Chart
            BloomCard(
              header: const BloomCardHeader(
                title: BloomCardTitle('Revenue Over Time'),
                description: BloomCardDescription('Monthly breakdown of desktop and mobile transactions.'),
              ),
              content: BloomChart(
                type: BloomChartType.area,
                height: 240,
                data: const BloomChartData(
                  labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                  series: [
                    BloomChartSeries(
                      name: 'Desktop',
                      values: [186, 305, 237, 73, 209, 214],
                      color: BloomColors.petalBlue,
                    ),
                    BloomChartSeries(
                      name: 'Mobile',
                      values: [80, 200, 120, 190, 130, 140],
                      color: BloomColors.petalPink,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}''',
  ),
  ApplicationBlock(
    id: 'auth-01',
    title: 'Clean Authentication Card',
    category: 'Authentication',
    description:
        'Sign-in form card with email input, password visibility '
        'toggle, remember me checkbox, and social auth buttons.',
    flutterCode: r'''import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

class AuthCardScreen extends StatelessWidget {
  const AuthCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: BloomCard(
            header: const BloomCardHeader(
              title: BloomCardTitle('Welcome Back'),
              description: BloomCardDescription('Enter your email to sign in to your account.'),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomField(
                  label: BloomFieldLabel('Email', required: true),
                  child: BloomInput(
                    placeholder: 'alex@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 16),
                const BloomField(
                  label: BloomFieldLabel('Password', required: true),
                  child: BloomInput(
                    placeholder: '••••••••',
                    obscureText: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BloomCheckbox(
                      checked: true,
                      label: const Text('Remember me'),
                      onChanged: (val) {},
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                BloomButton(
                  onPressed: () {
                    BloomSonner.success(context, 'Signed in successfully!');
                  },
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}''',
  ),
  ApplicationBlock(
    id: 'chat-01',
    title: 'AI Conversational Assistant',
    category: 'Chat & AI',
    description:
        'Complete AI messaging UI with message bubble reactions, '
        'file attachment pills, and bottom prompt bar.',
    flutterCode: r'''import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            BloomAvatar(name: 'Bloom AI', size: BloomAvatarSize.sm),
            SizedBox(width: 10),
            Text('Bloom Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                BloomMessage(
                  sender: BloomMessageSender(name: 'Bloom AI'),
                  bubble: BloomBubble(
                    variant: BloomBubbleVariant.received,
                    child: Text('Hello! How can I help configure your Flutter app today?'),
                  ),
                ),
                SizedBox(height: 16),
                BloomMessage(
                  sender: BloomMessageSender(name: 'You'),
                  bubble: BloomBubble(
                    variant: BloomBubbleVariant.sent,
                    child: Text('Can you generate a responsive data table layout?'),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface1,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BloomInput(
                    placeholder: 'Ask Bloom anything...',
                    leading: const Icon(Icons.auto_awesome, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                BloomButton(
                  size: BloomButtonSize.defaultSize,
                  onPressed: () {},
                  child: const Icon(Icons.arrow_upward, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}''',
  ),
  ApplicationBlock(
    id: 'settings-01',
    title: 'App Settings & Preferences',
    category: 'Settings',
    description:
        'Account profile, appearance theme toggle, push '
        'notification switches, and danger zone actions.',
    flutterCode: r'''import 'package:flutter/material.dart';
import 'package:bloom_ui/bloom_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          BloomCard(
            header: const BloomCardHeader(
              title: BloomCardTitle('Appearance & Notifications'),
              description: BloomCardDescription('Configure how Bloom UI looks and alerts you.'),
            ),
            content: Column(
              children: [
                BloomSwitch(
                  checked: true,
                  label: const Text('Dark Mode Sync'),
                  onChanged: (v) {},
                ),
                const SizedBox(height: 16),
                BloomSwitch(
                  checked: true,
                  label: const Text('OTA Patch Notifications'),
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}''',
  ),
];
