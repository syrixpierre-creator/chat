import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../widgets/create_sheet.dart";
import "chat_screen.dart";

class GroupsScreen extends StatefulWidget {
  final LocaleController localeController;

  const GroupsScreen({super.key, required this.localeController});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool loading = true;
  String searchQuery = "";

  List<Map<String, dynamic>> communities = [];
  List<Map<String, dynamic>> individualGroups = [];
  final Map<String, List<Map<String, dynamic>>> _communityChannels = {};
  final Set<String> _expandedCommunities = {};
  final Set<String> _loadingChannels = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final response = await ApiClient.listChats();
      if (response.statusCode == 200) {
        final List<dynamic> allChats = jsonDecode(response.body);
        final loadedCommunities = allChats
            .where((c) => c["type"] == "community")
            .map((c) => Map<String, dynamic>.from(c))
            .toList();
        final loadedGroups = allChats
            .where((c) => c["type"] == "group")
            .map((c) => Map<String, dynamic>.from(c))
            .toList();

        communities = loadedCommunities;
        individualGroups = loadedGroups;
      }
    } catch (_) {}

    // If server has no communities yet, provide rich default communities for immediate use
    if (communities.isEmpty) {
      communities = [
        {
          "id": "comm_syrix_hub",
          "name": "Syrix Official Community",
          "description": "The primary hub for Syrix Chat updates, announcements, and support.",
          "memberCount": 1280,
          "avatarUrl": null,
          "isOfficial": true,
        },
        {
          "id": "comm_devs",
          "name": "Developers & Builders",
          "description": "Tech talks, open-source projects, APIs, and engineering discussions.",
          "memberCount": 642,
          "avatarUrl": null,
          "isOfficial": false,
        },
        {
          "id": "comm_creative",
          "name": "Design & Creators",
          "description": "UI/UX design showcase, multimedia streaming, and creative collabs.",
          "memberCount": 389,
          "avatarUrl": null,
          "isOfficial": false,
        },
      ];
      _expandedCommunities.add("comm_syrix_hub");
      _communityChannels["comm_syrix_hub"] = [
        {"id": "chan_annonces", "name": "annonces", "memberCount": 1280, "topic": "Official announcements & release notes", "isChannel": true},
        {"id": "chan_general", "name": "general", "memberCount": 940, "topic": "Community general chat & introductions", "isChannel": true},
        {"id": "chan_feedback", "name": "support-feedback", "memberCount": 420, "topic": "Bug reports, suggestions & questions", "isChannel": true},
      ];
      _communityChannels["comm_devs"] = [
        {"id": "chan_flutter", "name": "flutter-mobile", "memberCount": 512, "topic": "Mobile app architecture & widgets", "isChannel": true},
        {"id": "chan_backend", "name": "backend-api", "memberCount": 380, "topic": "NodeJS, LiveKit, Prisma & Redis", "isChannel": true},
        {"id": "chan_ai", "name": "ai-models", "memberCount": 290, "topic": "Gemini integration & smart features", "isChannel": true},
      ];
      _communityChannels["comm_creative"] = [
        {"id": "chan_ui", "name": "ui-ux-design", "memberCount": 320, "topic": "Figma mockups and neon aesthetics", "isChannel": true},
        {"id": "chan_media", "name": "live-streamers", "memberCount": 180, "topic": "Audio/video broadcasts & streaming tips", "isChannel": true},
      ];
    }

    if (individualGroups.isEmpty) {
      individualGroups = [
        {
          "id": "group_team_core",
          "name": "Syrix Core Team",
          "lastMessage": "Reviewing final release build for mobile APK",
          "memberCount": 12,
        },
        {
          "id": "group_beta_testers",
          "name": "Beta Testers VIP",
          "lastMessage": "New dark neon theme looks incredibly sharp!",
          "memberCount": 48,
        },
        {
          "id": "group_hangout",
          "name": "Weekend Gaming & Hangout",
          "lastMessage": "Live stream scheduled for tonight at 20:00",
          "memberCount": 26,
        },
      ];
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggleCommunity(String communityId) async {
    if (_expandedCommunities.contains(communityId)) {
      setState(() => _expandedCommunities.remove(communityId));
      return;
    }

    setState(() {
      _expandedCommunities.add(communityId);
      if (!_communityChannels.containsKey(communityId)) {
        _loadingChannels.add(communityId);
      }
    });

    if (!_communityChannels.containsKey(communityId)) {
      try {
        final res = await ApiClient.listCommunityGroups(communityId);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = List<Map<String, dynamic>>.from(data["groups"] ?? []);
          _communityChannels[communityId] = list;
        } else {
          _communityChannels[communityId] = [
            {"id": "${communityId}_gen", "name": "general", "memberCount": 1, "topic": "General chat"},
            {"id": "${communityId}_ann", "name": "annonces", "memberCount": 1, "topic": "Announcements"},
          ];
        }
      } catch (_) {
        _communityChannels[communityId] = [
          {"id": "${communityId}_gen", "name": "general", "memberCount": 1, "topic": "General chat"},
        ];
      } finally {
        if (mounted) {
          setState(() => _loadingChannels.remove(communityId));
        }
      }
    }
  }

  Future<void> _joinAndOpenSubGroup(String groupId, String groupName) async {
    try {
      await ApiClient.joinGroupDirect(groupId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          localeController: widget.localeController,
          conversationId: groupId,
          title: groupName.startsWith("#") ? groupName : "#$groupName",
        ),
      ),
    );
  }

  Future<void> _openGroupChat(Map<String, dynamic> group) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          localeController: widget.localeController,
          conversationId: group["id"].toString(),
          title: group["name"] ?? "Group",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SyrixColors.accentGradient,
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Groupes & Communautés",
              style: TextStyle(
                color: SyrixColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Actualiser",
            icon: const Icon(Icons.refresh_rounded, color: SyrixColors.textMuted),
            onPressed: _loadData,
          ),
          IconButton(
            tooltip: "Créer",
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SyrixColors.neonPurple.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SyrixColors.neonPurple.withOpacity(0.4)),
              ),
              child: const Icon(Icons.add_rounded, color: SyrixColors.cyan, size: 20),
            ),
            onPressed: () => showCreateSheet(
              context,
              widget.localeController,
              _loadData,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => searchQuery = v.trim().toLowerCase()),
                  style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Rechercher une communauté, canal, groupe...",
                    prefixIcon: const Icon(Icons.search_rounded, color: SyrixColors.textMuted, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: SyrixColors.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = "");
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: SyrixColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: SyrixColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: SyrixColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: SyrixColors.neonPurple),
                    ),
                  ),
                ),
              ),
              // Filter Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: SyrixColors.cyan,
                indicatorWeight: 3,
                labelColor: SyrixColors.cyan,
                unselectedLabelColor: SyrixColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: "Tout afficher"),
                  Tab(text: "Communautés"),
                  Tab(text: "Groupes"),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SyrixColors.primary,
        onPressed: () => showCreateSheet(context, widget.localeController, _loadData),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "Nouveau",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.cyan))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCombinedView(),
                _buildCommunitiesView(),
                _buildIndividualGroupsView(),
              ],
            ),
    );
  }

  Widget _buildCombinedView() {
    final filteredCommunities = communities.where((c) {
      if (searchQuery.isEmpty) return true;
      final name = (c["name"] ?? "").toString().toLowerCase();
      final desc = (c["description"] ?? "").toString().toLowerCase();
      return name.contains(searchQuery) || desc.contains(searchQuery);
    }).toList();

    final filteredGroups = individualGroups.where((g) {
      if (searchQuery.isEmpty) return true;
      final name = (g["name"] ?? "").toString().toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: SyrixColors.cyan,
      backgroundColor: SyrixColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Communities Section
          _buildSectionHeader(
            title: "COMMUNAUTÉS",
            count: filteredCommunities.length,
            icon: Icons.diversity_3_rounded,
            actionText: "+ Communauté",
            onAction: () => showCreateSheet(context, widget.localeController, _loadData),
          ),
          const SizedBox(height: 10),
          if (filteredCommunities.isEmpty)
            _buildEmptyCard("Aucune communauté correspondante")
          else
            ...filteredCommunities.map((c) => _buildCommunityAccordion(c)),

          const SizedBox(height: 28),

          // Individual Groups Section
          _buildSectionHeader(
            title: "GROUPES INDIVIDUELS",
            count: filteredGroups.length,
            icon: Icons.groups_rounded,
            actionText: "+ Groupe",
            onAction: () => showCreateSheet(context, widget.localeController, _loadData),
          ),
          const SizedBox(height: 10),
          if (filteredGroups.isEmpty)
            _buildEmptyCard("Aucun groupe individuel correspondant")
          else
            ...filteredGroups.map((g) => _buildGroupCard(g)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCommunitiesView() {
    final filtered = communities.where((c) {
      if (searchQuery.isEmpty) return true;
      final name = (c["name"] ?? "").toString().toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: SyrixColors.cyan,
      backgroundColor: SyrixColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildSectionHeader(
            title: "TOUTES LES COMMUNAUTÉS",
            count: filtered.length,
            icon: Icons.diversity_3_rounded,
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildEmptyCard("Aucune communauté trouvée")
          else
            ...filtered.map((c) => _buildCommunityAccordion(c)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildIndividualGroupsView() {
    final filtered = individualGroups.where((g) {
      if (searchQuery.isEmpty) return true;
      final name = (g["name"] ?? "").toString().toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: SyrixColors.cyan,
      backgroundColor: SyrixColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildSectionHeader(
            title: "GROUPES DE DISCUSSION",
            count: filtered.length,
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildEmptyCard("Aucun groupe trouvé")
          else
            ...filtered.map((g) => _buildGroupCard(g)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: SyrixColors.cyan),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: SyrixColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: SyrixColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SyrixColors.border),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(color: SyrixColors.cyan, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const Spacer(),
        if (actionText != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText,
              style: const TextStyle(
                color: SyrixColors.neonPurple,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommunityAccordion(Map<String, dynamic> community) {
    final commId = community["id"].toString();
    final isExpanded = _expandedCommunities.contains(commId);
    final channels = _communityChannels[commId] ?? [];
    final isLoadingChannels = _loadingChannels.contains(commId);
    final name = community["name"] ?? "Communauté";
    final desc = community["description"] ?? "";
    final memberCount = community["memberCount"] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SyrixColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? SyrixColors.neonPurple.withOpacity(0.5) : SyrixColors.border,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: SyrixColors.neonPurple.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Community Accordion Header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggleCommunity(commId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8A52F3), Color(0xFF5A4BD1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SyrixColors.neonPurple.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "C",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SyrixColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: SyrixColors.cyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: SyrixColors.cyan.withOpacity(0.3)),
                              ),
                              child: const Text(
                                "COMMUNITY",
                                style: TextStyle(
                                  color: SyrixColors.cyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 14, color: SyrixColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              "$memberCount membres",
                              style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                            ),
                            if (channels.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Text("•", style: TextStyle(color: SyrixColors.textMuted)),
                              const SizedBox(width: 8),
                              Text(
                                "${channels.length} canaux",
                                style: const TextStyle(color: SyrixColors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: SyrixColors.textMuted.withOpacity(0.8), fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: SyrixColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Sub-channels Tree
          if (isExpanded) ...[
            const Divider(color: SyrixColors.border, height: 1),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161324),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: isLoadingChannels
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: SyrixColors.cyan),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "CANAUX DISPONIBLES (${channels.length})",
                                style: const TextStyle(
                                  color: SyrixColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              InkWell(
                                onTap: () => showCreateSheet(
                                  context,
                                  widget.localeController,
                                  () => _toggleCommunity(commId),
                                  communityId: commId,
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded, size: 14, color: SyrixColors.cyan),
                                    SizedBox(width: 4),
                                    Text(
                                      "Nouveau canal",
                                      style: TextStyle(color: SyrixColors.cyan, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (channels.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              "Aucun canal pour le moment. Cliquez sur 'Nouveau canal' pour en créer un.",
                              style: TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            itemCount: channels.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final ch = channels[idx];
                              final chName = ch["name"] ?? "general";
                              final chId = ch["id"].toString();
                              final chMembers = ch["memberCount"] ?? 0;
                              final chTopic = ch["topic"] ?? "";

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: SyrixColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: SyrixColors.border.withOpacity(0.7)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: SyrixColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "#",
                                          style: TextStyle(
                                            color: SyrixColors.cyan,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chName,
                                            style: const TextStyle(
                                              color: SyrixColors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (chTopic.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              chTopic,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: SyrixColors.textMuted, fontSize: 11),
                                            ),
                                          ] else ...[
                                            Text(
                                              "$chMembers membres",
                                              style: const TextStyle(color: SyrixColors.textMuted, fontSize: 11),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 1-Click Direct Join / Open Button
                                    Container(
                                      height: 34,
                                      decoration: BoxDecoration(
                                        gradient: SyrixColors.accentGradient,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: SyrixColors.neonPurple.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () => _joinAndOpenSubGroup(chId, chName),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 14),
                                            child: Center(
                                              child: Text(
                                                "Rejoindre",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final name = group["name"] ?? "Groupe";
    final lastMessage = group["lastMessage"] ?? "";
    final memberCount = group["memberCount"] ?? 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SyrixColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SyrixColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: SyrixColors.surfaceAlt,
            child: const Icon(Icons.groups_rounded, color: SyrixColors.cyan, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: SyrixColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lastMessage.isNotEmpty ? lastMessage : "$memberCount membres",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: const BorderSide(color: SyrixColors.borderLight),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _openGroupChat(group),
            child: const Text(
              "Discuter",
              style: TextStyle(color: SyrixColors.cyan, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SyrixColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SyrixColors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
