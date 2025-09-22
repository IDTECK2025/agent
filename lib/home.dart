import 'package:agents/agent.dart';
import 'package:agents/api.dart';
import 'package:agents/forgotpassword.dart';
import 'package:agents/main.dart';
import 'package:agents/subagnet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Your existing model classes remain the same
class WalletData {
  final String id;
  final String name;
  final String role;
  final Wallet wallet;

  WalletData({
    required this.id,
    required this.name,
    required this.role,
    required this.wallet,
  });

  factory WalletData.fromJson(Map<String, dynamic> json) {
    return WalletData(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      wallet: Wallet.fromJson(json['wallet']),
    );
  }
}

class Wallet {
  final double balance;
  final List<Transaction> ledger;

  Wallet({required this.balance, required this.ledger});

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      balance: json['balance'].toDouble(),
      ledger: (json['ledger'] as List)
          .map((item) => Transaction.fromJson(item))
          .toList(),
    );
  }
}

class Transaction {
  final double amount;
  final String note;
  final String payment;
  final DateTime createdAt;

  Transaction({
    required this.amount,
    required this.note,
    required this.payment,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      amount: json['amount'].toDouble(),
      note: json['note'],
      payment: json['payment'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

// Enhanced API Service with logout
class WalletService {
  Future<WalletData> fetchWalletData(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token'); // Retrieve stored token

      final response = await http.get(
        Uri.parse('${ApiConfig.api}/users/wallet/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',  // Add Bearer Token here
        },
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return WalletData.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load wallet data');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Logout method to clear stored data
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('login_time');
    await prefs.clear();
  }
}


// Enhanced Wallet Page
class WalletPage extends StatefulWidget {
  final String userId;

  const WalletPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  WalletData? _walletData;
  bool _isLoading = false;
  String? _error;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchWalletData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final walletData = await _walletService.fetchWalletData(widget.userId);
      setState(() {
        _walletData = walletData;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    _animationController.reset();
    await _fetchWalletData();
  }

  // Manual refresh method for tap-to-refresh
  Future<void> _manualRefresh() async {
    await _onRefresh();

    // Show a brief success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Wallet refreshed successfully!'),
          ],
        ),
        backgroundColor: Color(0xFF4CAF50),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Logout method with confirmation dialog
  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFE91E63)),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            'Are you sure you want to logout? You will need to sign in again to access your wallet.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                child: Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _performLogout();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Perform logout operation
  // Perform logout operation
  Future<void> _performLogout() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                ),
                SizedBox(height: 16),
                Text('Logging out...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );

    try {
      // 🔹 Clear stored data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // removes all keys (auth_token, user_id, etc.)
      // or if you only want to remove specific keys:
      // await prefs.remove('auth_token');
      // await prefs.remove('user_data');
      // await prefs.remove('user_id');
      // await prefs.remove('login_time');

      // 🔹 Close loading dialog
      Navigator.of(context).pop();

      // 🔹 Navigate to Login Page (replace with your LoginScreen)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false, // removes all previous routes
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        backgroundColor: Color(0xFF1D1E33),
        color: Color(0xFF667eea),
        child: CustomScrollView(
          slivers: [
            // Enhanced App Bar with Logout
            SliverAppBar(
              automaticallyImplyLeading: false,
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Color(0xFF1D1E33),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              actions: [
                // Refresh Button
                Container(
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Icon(Icons.refresh, color: Colors.white),
                              );
                            },
                          )
                        : Icon(Icons.refresh, color: Colors.white),
                    onPressed: _isLoading ? null : _fetchWalletData,
                    tooltip: 'Refresh wallet data',
                  ),
                ),
                // Logout Button
                Container(
                  margin: EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.logout, color: Colors.white),
                    onPressed: _showLogoutDialog,
                    tooltip: 'Logout',
                  ),
                ),
              ],
            ),

            // Main Content
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _walletData == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF1D1E33),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF667eea).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Loading your wallet...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF1D1E33),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.redAccent,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!.replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ElevatedButton(
                  onPressed: _fetchWalletData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_walletData == null) {
      return Center(child: Text('No data available'));
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  _buildBalanceCard(),
                  SizedBox(height: 20),

                  // User Info Card
                  _buildUserInfoCard(),
                  SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActions(),
                  SizedBox(height: 20),

                  // Transaction History Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Transaction List
                  _buildTransactionList(),

                  SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Pull down to refresh ✨',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF1D1E33),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: _manualRefresh,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      color: Color(0xFF667eea),
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to refresh',
                                      style: TextStyle(
                                        color: Color(0xFF667eea),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '\$${_walletData!.wallet.balance.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.greenAccent, size: 16),
              SizedBox(width: 4),
              Text(
                '+2.5% from last month',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _walletData!.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF667eea).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _walletData!.role,
                    style: TextStyle(
                      color: Color(0xFF667eea),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getStoredUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.person,
            label: 'Add customer',
            color: Color(0xFF4CAF50),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CustomerForm()),
              );
            },
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.send,
            label: 'Send Money',
            color: Color(0xFF2196F3),
            onTap: () {},
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.person,
            label: 'Add Agent',
            color: Color(0xFFFF9800),
            onTap: () async {
              final role = await _getStoredUserRole();

              if (role == 'SHAREHOLDER') {
                // ✅ Shareholder can add Agent
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ShareHolderForm()),
                );
              } else if (role == 'AGENT') {
                // ✅ Agent can add SubAgent
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => subagent()),
                );
              } else {
                // ❌ Others cannot
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '❌ Access denied',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_walletData!.wallet.ledger.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, color: Colors.white38, size: 48),
            SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _walletData!.wallet.ledger
          .asMap()
          .entries
          .map((entry) => _buildTransactionItem(entry.value, entry.key))
          .toList(),
    );
  }

  Widget _buildTransactionItem(Transaction transaction, int index) {
    final isCredit = transaction.amount > 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isCredit
                  ? Color(0xFF4CAF50).withOpacity(0.2)
                  : Color(0xFFE91E63).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? Color(0xFF4CAF50) : Color(0xFFE91E63),
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year} • ${transaction.createdAt.hour}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}\$${transaction.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: isCredit ? Color(0xFF4CAF50) : Color(0xFFE91E63),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCredit ? 'Credit' : 'Debit',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
