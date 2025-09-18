import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/balloon_background.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

/// Main screen displaying real-time gender reveal voting results
/// 
/// This screen shows animated balloons in the background, real-time vote
/// counts for boy vs girl predictions, and handles the gender reveal moment.
class GenderRevealScreen extends StatefulWidget {
  const GenderRevealScreen({super.key});

  @override
  State<GenderRevealScreen> createState() => _GenderRevealScreenState();
}

class _GenderRevealScreenState extends State<GenderRevealScreen> {
  /// Current number of votes for boy prediction
  int boyVotes = 0;
  
  /// Current number of votes for girl prediction
  int girlVotes = 0;
  
  /// Whether the gender has been revealed
  bool isRevealed = false;
  
  /// Stream subscription for Firestore updates
  late Stream<DocumentSnapshot> _firestoreStream;
  
  @override
  void initState() {
    super.initState();
    _setupFirestoreListener();
  }
  
  /// Sets up real-time listener for Firestore vote updates
  /// 
  /// This method creates a stream that listens to changes in the
  /// gender reveal document and updates the UI accordingly.
  void _setupFirestoreListener() {
    _firestoreStream = FirestoreService.getGenderRevealStream();
  }
  
  /// Triggers the gender reveal by updating Firestore
  /// 
  /// This method calls the FirestoreService to set the reveal flag,
  /// which will notify all connected devices to show the result.
  Future<void> _triggerReveal() async {
    try {
      await FirestoreService.triggerReveal();
    } catch (e) {
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger reveal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Resets the voting event (useful for testing or new events)
  Future<void> _resetEvent() async {
    try {
      await FirestoreService.resetGenderRevealEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event has been reset'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Animated balloon background
          const Positioned.fill(
            child: BalloonBackground(enableAnimation: true),
          ),
          
          // Semi-transparent overlay for better text readability
          _buildOverlay(),
          
          // Main content with voting results
          _buildMainContent(),
          
          // Reset button in top-right corner (for testing)
          _buildResetButton(),
        ],
      ),
    );
  }
  
  /// Builds the app bar with user information and sign-out option
  PreferredSizeWidget _buildAppBar() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);
    
    return AppBar(
      title: const Text(
        '宝宝性别揭晓派对',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.pink.withValues(alpha: 0.8),
              Colors.blue.withValues(alpha: 0.8),
            ],
          ),
        ),
      ),
      actions: [
        // User profile display with better visibility
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User name display (visible on wider screens)
              if (MediaQuery.of(context).size.width > 500) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            blurRadius: 2.0,
                            color: Colors.black26,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user?.email != null && !AuthService.isAnonymous)
                      Text(
                        user!.email!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          shadows: [
                            Shadow(
                              blurRadius: 2.0,
                              color: Colors.black26,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (AuthService.isAnonymous)
                      const Text(
                        'Guest',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          shadows: [
                            Shadow(
                              blurRadius: 2.0,
                              color: Colors.black26,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              
              // Enhanced profile menu button
              PopupMenuButton<String>(
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).primaryColor,
                      size: 22,
                    ),
                  ),
                ),
                tooltip: 'User profile',
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'signout') {
                    _signOut();
                  } else if (value == 'profile') {
                    _showUserProfile();
                  }
                },
                itemBuilder: (context) => [
                  // Enhanced user info header
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                if (user?.email != null && !AuthService.isAnonymous)
                                  Text(
                                    user!.email!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (AuthService.isAnonymous)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Anonymous Guest',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AuthService.isAnonymous 
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AuthService.isAnonymous 
                                          ? Colors.orange.withValues(alpha: 0.3)
                                          : Colors.green.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    AuthService.isAnonymous ? 'Guest Session' : 'Authenticated',
                                    style: TextStyle(
                                      color: AuthService.isAnonymous 
                                          ? Colors.orange[700]
                                          : Colors.green[700],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  
                  // View Profile option
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.account_circle_outlined),
                        SizedBox(width: 12),
                        Text('View Profile'),
                      ],
                    ),
                  ),
                  
                  // Sign out option
                  const PopupMenuItem<String>(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
  
  /// Handle user sign-out
  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      // The AuthWrapper will automatically redirect to login screen
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Builds the semi-transparent overlay for better text visibility
  Widget _buildOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
      ),
    );
  }
  
  /// Builds the main content area with voting results and controls
  Widget _buildMainContent() {
    return Center(
      child: StreamBuilder<DocumentSnapshot>(
        stream: _firestoreStream,
        builder: (context, snapshot) {
          // Update local state from Firestore data
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              boyVotes = data['boyVotes'] ?? 0;
              girlVotes = data['girlVotes'] ?? 0;
              isRevealed = data['isRevealed'] ?? false;
            }
          }
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWelcomeMessage(),
              const SizedBox(height: 20),
              _buildTitle(),
              const SizedBox(height: 40),
              _buildVotingChart(),
              const SizedBox(height: 20),
              _buildLegend(),
              const SizedBox(height: 40),
              if (!isRevealed) _buildRevealButton(),
              if (isRevealed) _buildRevealResult(),
              if (snapshot.hasError) _buildErrorMessage(snapshot.error.toString()),
            ],
          );
        },
      ),
    );
  }
  
  /// Builds welcome message with user name
  Widget _buildWelcomeMessage() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.person,
              color: Theme.of(context).primaryColor,
              size: 18,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Welcome text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '欢迎, ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (AuthService.isAnonymous)
                    Icon(
                      Icons.visibility_off,
                      size: 14,
                      color: Colors.orange[600],
                    )
                  else
                    Icon(
                      Icons.verified,
                      size: 14,
                      color: Colors.green[600],
                    ),
                ],
              ),
              Text(
                AuthService.isAnonymous 
                    ? 'Welcome! • Guest Session'
                    : 'Welcome! • Ready to vote',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Builds the main title
  Widget _buildTitle() {
    return const Text(
      '实时投票结果',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [
          Shadow(
            blurRadius: 10.0,
            color: Colors.black,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
    );
  }
  
  /// Builds the horizontal bar chart showing vote distribution
  Widget _buildVotingChart() {
    final total = boyVotes + girlVotes;
    
    return SizedBox(
      width: 300,
      child: Row(
        children: [
          // Boy votes bar (blue)
          Expanded(
            flex: total > 0 ? boyVotes : 1,
            child: Container(
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  '$boyVotes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          
          // Girl votes bar (pink)
          Expanded(
            flex: total > 0 ? girlVotes : 1,
            child: Container(
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.pink,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  '$girlVotes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds the legend showing color coding for vote types
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.blue, '男宝宝'),
        const SizedBox(width: 30),
        _buildLegendItem(Colors.pink, '女宝宝'),
      ],
    );
  }
  
  /// Builds a single legend item with color square and label
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          color: color,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ],
    );
  }
  
  /// Builds the reveal button (shown before gender is revealed)
  Widget _buildRevealButton() {
    return ElevatedButton(
      onPressed: _triggerReveal,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: const Text(
        '揭晓答案!',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
  
  /// Builds the reveal result (shown after gender is revealed)
  Widget _buildRevealResult() {
    final isboy = boyVotes > girlVotes;
    final resultText = isboy ? '是男宝宝! 👶' : '是女宝宝! 👧';
    final resultColor = isboy ? Colors.blue : Colors.pink;
    
    return Text(
      resultText,
      style: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.bold,
        color: resultColor,
        shadows: const [
          Shadow(
            blurRadius: 10.0,
            color: Colors.white,
            offset: Offset(2.0, 2.0),
          ),
        ],
      ),
    );
  }
  
  /// Builds error message widget
  Widget _buildErrorMessage(String error) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Error: $error',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
  
  /// Builds the reset button for testing purposes
  Widget _buildResetButton() {
    return Positioned(
      top: 50,
      right: 20,
      child: FloatingActionButton(
        mini: true,
        onPressed: _resetEvent,
        backgroundColor: Colors.grey.withValues(alpha: 0.7),
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  /// Show detailed user profile dialog
  void _showUserProfile() {
    final User? user = AuthService.currentUser;
    final String displayName = AuthService.getUserDisplayName(user);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile header
              Row(
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 28,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'User Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Profile picture
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    width: 100,
                    height: 100,
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).primaryColor,
                      size: 50,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // User name
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // User email or status
              if (user?.email != null && !AuthService.isAnonymous)
                Text(
                  user!.email!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 16),
              
              // Authentication status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AuthService.isAnonymous 
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AuthService.isAnonymous 
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AuthService.isAnonymous 
                          ? Icons.visibility_off 
                          : Icons.verified_user,
                      size: 16,
                      color: AuthService.isAnonymous 
                          ? Colors.orange[700]
                          : Colors.green[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AuthService.isAnonymous ? 'Anonymous Guest' : 'Authenticated User',
                      style: TextStyle(
                        color: AuthService.isAnonymous 
                            ? Colors.orange[700]
                            : Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // User details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildProfileDetailRow(
                      icon: Icons.fingerprint,
                      label: 'User ID',
                      value: user?.uid ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetailRow(
                      icon: Icons.access_time,
                      label: 'Account Created',
                      value: user?.metadata.creationTime != null 
                          ? '${user!.metadata.creationTime!.day}/${user.metadata.creationTime!.month}/${user.metadata.creationTime!.year}'
                          : 'Unknown',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetailRow(
                      icon: Icons.login,
                      label: 'Last Sign In',
                      value: user?.metadata.lastSignInTime != null 
                          ? '${user!.metadata.lastSignInTime!.day}/${user.metadata.lastSignInTime!.month}/${user.metadata.lastSignInTime!.year}'
                          : 'Unknown',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _signOut();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Helper method to build profile detail rows
  Widget _buildProfileDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}