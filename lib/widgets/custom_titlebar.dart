import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../models/app_state.dart';

class CustomTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onHome;
  final VoidCallback? onDownload;  // 下载器入口
  final VoidCallback? onToggleLanguage; // 切换语言
  final String pageTitle;
  final String? favIconUrl;
  final bool hasUrl;  // 是否有网址
  final int downloadCount;  // 下载任务数
  final AppState appState;
  
  const CustomTitleBar({
    super.key,
    this.onRefresh,
    this.onHome,
    this.onDownload,
    this.onToggleLanguage,
    this.pageTitle = 'Deskify',
    this.favIconUrl,
    this.hasUrl = false,
    this.downloadCount = 0,
    required this.appState,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: AppBar(
        backgroundColor: const Color(0xFF2C2C2C),
        toolbarHeight: 48,
        elevation: 0,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            // 网站图标
            if (favIconUrl != null && favIconUrl!.isNotEmpty)
              Image.network(
                favIconUrl!,
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 20,
                  );
                },
              )
            else
              const Icon(
                Icons.language,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
        leadingWidth: 44,
        title: Text(
          pageTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          // 工具栏按钮
          if (onHome != null)
            _ToolButton(
              icon: Icons.home,
              tooltip: appState.tr(zh: '首页', en: 'Home'),
              onPressed: onHome!,
            ),
          if (onRefresh != null)
            _ToolButton(
              icon: Icons.refresh,
              tooltip: appState.tr(zh: '刷新', en: 'Reload'),
              onPressed: onRefresh!,
            ),
          
          // 下载器入口
          if (onDownload != null)
            _ToolButton(
              icon: Icons.download_outlined,
              tooltip: downloadCount > 0
                  ? appState.tr(zh: '下载 ($downloadCount)', en: 'Downloads ($downloadCount)')
                  : appState.tr(zh: '下载', en: 'Downloads'),
              onPressed: onDownload!,
              badge: downloadCount > 0 ? downloadCount : null,
            ),
          
          // 语言切换按钮（紧凑胶囊样式）
          if (onToggleLanguage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: _LangButton(
                isEnglish: appState.isEnglish,
                tooltip: appState.tr(zh: '切换语言', en: 'Toggle language'),
                onTap: onToggleLanguage!,
              ),
            ),
          
          // 窗口控制按钮
          _WindowButton(
            icon: Icons.minimize,
            onPressed: () async {
              await windowManager.minimize();
            },
          ),
          _WindowButton(
            icon: Icons.crop_square,
            onPressed: () async {
              bool isMaximized = await windowManager.isMaximized();
              if (isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            icon: Icons.close,
            onPressed: () async {
              await windowManager.close();
            },
            isClose: true,
          ),
        ],
      ),
    );
  }
}

// 工具栏按钮
class _ToolButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int? badge;  // 徽章数字

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 44,
            height: 48,
            color: _isHovered ? const Color(0x1AFFFFFF) : Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 18,
                ),
                // 徽章
                if (widget.badge != null)
                  Positioned(
                    right: 8,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        widget.badge! > 99 ? '99+' : widget.badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 语言切换胶囊按钮
class _LangButton extends StatefulWidget {
  final bool isEnglish;
  final String tooltip;
  final VoidCallback onTap;

  const _LangButton({
    required this.isEnglish,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_LangButton> createState() => _LangButtonState();
}

class _LangButtonState extends State<_LangButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool en = widget.isEnglish;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _hovered ? const Color(0x1AFFFFFF) : Colors.transparent,
              border: Border.all(color: Colors.white24, width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EN',
                  style: TextStyle(
                    color: en ? Colors.white : Colors.white70,
                    fontWeight: en ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '中',
                  style: TextStyle(
                    color: en ? Colors.white70 : Colors.white,
                    fontWeight: en ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 48,
          height: 48,
          color: _isHovered
              ? (widget.isClose ? const Color(0xFFE81123) : const Color(0x1AFFFFFF))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }
}
