import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class BingoAiScreen extends StatefulWidget {
  const BingoAiScreen({super.key});

  @override
  State<BingoAiScreen> createState() => _BingoAiScreenState();
}

class _BingoAiScreenState extends State<BingoAiScreen> {
  final TextEditingController _controller = TextEditingController();
  late final List<Map<String, String>> _messages;
  String _userName = 'User';

  bool _isLoadingApis = false;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _messages = [
      {
        'sender': 'bingo',
        'text':
            'Hello! I am Bingo AI, your CRM assistant. How can I help you analyze your pipeline or drafts today?',
      },
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserAndLoadApis();
    });
  }

  /// Fetches user profile from AuthProvider or GET /auth/me API and updates the greeting name
  Future<void> _initUserAndLoadApis() async {
    if (!mounted) return;

    // 1. Check if AuthProvider already has the current logged in user
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser != null && currentUser.firstName.isNotEmpty) {
        _updateGreetingName(currentUser.firstName);
      }
    } catch (_) {}

    _loadAllApisAndConversations();
  }

  void _updateGreetingName(String name) {
    if (!mounted) return;
    setState(() {
      _userName = name;
      if (_messages.isNotEmpty && _messages[0]['sender'] == 'bingo') {
        _messages[0] = {
          'sender': 'bingo',
          'text':
              'Hello $_userName! I am Bingo AI, your CRM assistant. How can I help you analyze your pipeline or drafts today?',
        };
      }
    });
  }

  /// Calls all APIs including GET /auth/me to fetch user profile name dynamically
  Future<void> _loadAllApisAndConversations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingApis = true;
    });

    final api = ApiService();

    try {
      await Future.wait([
        // Fetch ME API dynamically to extract logged in user's first name
        api.get('/auth/me').then((res) {
          if (res.data != null && mounted) {
            final raw = res.data;
            debugPrint('[BingoAiScreen GET /auth/me response]: $raw');
            Map<String, dynamic>? userMap;
            if (raw is Map<String, dynamic>) {
              if (raw['data'] is Map<String, dynamic>) {
                userMap = raw['data'] as Map<String, dynamic>;
              } else if (raw['user'] is Map<String, dynamic>) {
                userMap = raw['user'] as Map<String, dynamic>;
              } else {
                userMap = raw;
              }
            }
            if (userMap != null) {
              final uname = userMap['username'] ??
                  userMap['user']?['username'] ??
                  userMap['firstName'] ??
                  userMap['first_name'] ??
                  userMap['user']?['firstName'] ??
                  userMap['name']?.toString().split(' ').first ??
                  userMap['email']?.toString().split('@').first;
              if (uname != null && uname.toString().trim().isNotEmpty) {
                _updateGreetingName(uname.toString().trim());
              }
            }
          }
          return res;
        }).catchError((e) => null),

        api.get('/activities/notifications').catchError((e) => null),
        api.get('/departments').catchError((e) => null),
        api.get('/lifecycle-stages?entityType=company').catchError((e) => null),
        api.get('/master-dropdowns/key/company_industry?includeInactive=false').catchError((e) => null),
        api.get('/master-dropdowns/key/company_type?includeInactive=false').catchError((e) => null),
        api.get('/contacts?page=1&limit=25').catchError((e) => null),
        api.get('/msp-options').catchError((e) => null),
        api.get('/lifecycle-stages?entityType=contact').catchError((e) => null),
        api.get('/companies?page=1&limit=25').catchError((e) => null),
        api.get('/master-dropdowns/key/contact_lead_status?includeInactive=false').catchError((e) => null),
        api.get('/deals/stages').catchError((e) => null),
        api.get('/deals?page=1&limit=25').catchError((e) => null),
        api.get('/activities/notifications?isRead=false&limit=10').catchError((e) => null),
        api.get('/auth/team').catchError((e) => null),
        api.get('/activities?ownerId=me').catchError((e) => null),
        api.get('/assistant/conversations').then((res) {
          if (res.data != null && mounted) {
            final raw = res.data;
            if (raw is Map<String, dynamic> && raw['data'] is List) {
              _conversations = (raw['data'] as List).whereType<Map<String, dynamic>>().toList();
            } else if (raw is List) {
              _conversations = raw.whereType<Map<String, dynamic>>().toList();
            }
          }
          return res;
        }).catchError((e) => null),
      ]);
    } catch (e) {
      debugPrint('[BingoAiScreen _loadAllApis error]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApis = false;
        });
      }
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _messages.add({
        'sender': 'bingo',
        'text':
            'I checked your active pipeline based on your query. You have 34 deals in progress across your CRM!',
      });
    });
    _controller.clear();
  }

  void _openPastConversationsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = _conversations.where((conv) {
              final title = conv['title'] ?? '';
              return title.toString().toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top Title & Close Button - White background & Green inside shape
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF00A884), // Green inside shape
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Past Conversations',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Chat Input Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: Color(0xFF00A884)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setModalState(() {
                                searchQuery = val;
                              });
                            },
                            style: GoogleFonts.poppins(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search chat history...',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Conversations List (White background, Green inside shape)
                  Expanded(
                    child: filteredList.isNotEmpty
                        ? ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              final title = item['title'] ?? 'Untitled Conversation';
                              final createdAt = item['createdAt'] ?? '';

                              String dateDisplay = '';
                              if (createdAt.isNotEmpty) {
                                try {
                                  final dt = DateTime.parse(createdAt.toString());
                                  dateDisplay = '${dt.day}/${dt.month}/${dt.year}';
                                } catch (_) {}
                              }

                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  setState(() {
                                    _messages.clear();
                                    _messages.add({
                                      'sender': 'user',
                                      'text': title.toString(),
                                    });
                                    _messages.add({
                                      'sender': 'bingo',
                                      'text': 'Here is the summary and context for "$title".',
                                    });
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: Color(0xFF00A884), // Green inside shape
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title.toString(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1E293B),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (dateDisplay.isNotEmpty)
                                              Text(
                                                dateDisplay,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11.5,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFFCBD5E1),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 36, color: Color(0xFF00A884)),
                              const SizedBox(height: 8),
                              Text(
                                'No conversations found',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Ask Bingo AI title & Green Bingo AI icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Green Background Icon Container (same as sidebar Bingo AI icon)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00A884), // Green background color
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white, // White icon inside green background
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Ask Bingo AI',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),

                  // History Icon Button: White Background, Inside Shape/Icon Color Green
                  InkWell(
                    onTap: _openPastConversationsModal,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF00A884), // Green inside shape/icon color
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Chat Messages List View
            Expanded(
              child: _isLoadingApis
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final bool isUser = msg['sender'] == 'user';

                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            constraints: const BoxConstraints(maxWidth: 300),
                            decoration: BoxDecoration(
                              color: isUser ? const Color(0xFF00A884) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              msg['text']!,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                color: isUser ? Colors.white : const Color(0xFF1E293B),
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Chat Input Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.poppins(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Ask Bingo anything about your CRM...',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF00A884), size: 22),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
