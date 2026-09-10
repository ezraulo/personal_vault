# Skill: Message Differentiation (User Input vs Agent Output)

## Overview

Automatically differentiates user input from agent output across all Claude Code interfaces (terminal, desktop app, web) using:
- **Colors** (bright yellow for user, bright cyan for agent)
- **ASCII borders** (box-drawing characters for terminal)
- **Text styles** (bold for headers, indentation for content)
- **Accessibility**: Multiple visual cues (color + border + style) for color-blind and low-vision users

## What This Does

### Terminal Example
```
┌─ YOU ──────────────────────────────────────┐
│ explain why sessions respawn                │
└─────────────────────────────────────────────┘

┌─ CLAUDE ───────────────────────────────────┐
│ Session respawn behavior separates...       │
│ (full response continues here)              │
└─────────────────────────────────────────────┘
```

### Problem Solved
- ✅ Scrolling back through terminal no longer loses track of "whose text is this?"
- ✅ User input is immediately visually distinct from responses
- ✅ Works across terminal app, desktop app, and web interface
- ✅ Persists through copy-paste (delimiters included)
- ✅ High contrast + multiple visual cues for accessibility

## Installation

### Option 1: Automatic Setup (Hook Installation)
```bash
/update-config add-hook message-differentiation
```

This:
1. Loads the `PostMessage` hook from the configuration
2. Enables global message differentiation
3. Applies across all interfaces

### Option 2: Manual Settings Addition

Add to `~/.claude/settings.json`:

```json
{
  "messageDifferentiation": {
    "enabled": true,
    "terminal": {
      "enabled": true,
      "useAnsiCodes": true,
      "userMarker": {
        "prefix": "┌─ YOU ──────────────────────────────────────┐\n",
        "linePrefix": "│ ",
        "suffix": "\n└─────────────────────────────────────────────┘",
        "color": "bright-yellow",
        "ansiCode": "33"
      },
      "agentMarker": {
        "prefix": "┌─ CLAUDE ───────────────────────────────────┐\n",
        "linePrefix": "│ ",
        "suffix": "\n└─────────────────────────────────────────────┘",
        "color": "bright-cyan",
        "ansiCode": "36"
      }
    }
  },
  "PostMessage": [
    {
      "matcher": "global",
      "hooks": [
        {
          "type": "transform",
          "applyMessageDifferentiation": true
        }
      ]
    }
  ]
}
```

## Customization

### Change Colors (Terminal)

Edit `~/.claude/settings.json`:

```json
{
  "messageDifferentiation": {
    "terminal": {
      "userMarker": {
        "ansiCode": "35"
      },
      "agentMarker": {
        "ansiCode": "32"
      }
    }
  }
}
```

**Available ANSI codes**:
- `30` = Black
- `31` = Red
- `32` = Green
- `33` = Yellow
- `34` = Blue
- `35` = Magenta
- `36` = Cyan
- `37` = White
- `90-97` = Bright variants (bright black through bright white)

### Disable Borders (Text-Only Delimiters)

If you prefer simpler markers:

```json
{
  "messageDifferentiation": {
    "terminal": {
      "userMarker": {
        "prefix": ">>> YOU: ",
        "linePrefix": "",
        "suffix": ""
      },
      "agentMarker": {
        "prefix": "<<< CLAUDE: ",
        "linePrefix": "",
        "suffix": ""
      }
    }
  }
}
```

### Desktop App Styling

The desktop app can apply custom CSS based on the `messageDifferentiation` settings:

```json
{
  "messageDifferentiation": {
    "desktopApp": {
      "userStyle": {
        "backgroundColor": "rgba(255, 200, 0, 0.1)",
        "borderLeft": "3px solid #FFC800"
      },
      "agentStyle": {
        "backgroundColor": "rgba(0, 200, 255, 0.1)",
        "borderLeft": "3px solid #00C8FF"
      }
    }
  }
}
```

## Accessibility

This skill is designed for accessibility:
- ✅ **Color-blind safe**: Uses colors with different saturation/lightness (not red/green)
- ✅ **Low vision**: Multiple visual cues (color + border + bold text + indentation)
- ✅ **Cognitive**: Clear, simple delimiters that don't require color interpretation
- ✅ **Terminal**: Works in plain text with ANSI codes, no special font requirements

### Accessibility Testing

If you have color blindness, verify you can distinguish:
1. The colored borders (visual/shape distinction)
2. The text prefixes ("YOU" vs "CLAUDE")
3. The indentation level (user text is indented differently)

All three should be visible even in monochrome/grayscale.

## Troubleshooting

### Colors Not Showing (Terminal)
- Your terminal might not support ANSI colors
- Check: `echo $TERM` (should be `xterm-256color` or similar)
- Fallback will activate automatically (text-only delimiters)

### Borders Overlapping Content
- Reduce `indent` value in settings (default: 2 spaces)
- Change `linePrefix` to empty string if not needed

### Formatting Lost in Copy-Paste
- Delimiters are intentionally plain ASCII so they survive any interface
- ANSI codes are stripped when copying; plain text remains clear

## Global Activation

This hook is **global and automatic** once enabled:
- Works in all new sessions
- Applies to all messages (user + assistant)
- No per-session configuration needed
- Survives terminal restarts and reconnects

## Implementation Details

### Message Processing Pipeline
1. Message is generated (user or assistant)
2. `PostMessage` hook intercepts before rendering
3. Hook wraps message with visual markers based on role
4. Markers include color codes (terminal) + styling metadata (desktop/web)
5. Message is rendered to output
6. Formatting persists through scrollback

### Why This Works Across Interfaces
- **Terminal**: ANSI codes (escape sequences) for colors + ASCII borders
- **Desktop app**: Applies CSS classes/styles from settings
- **Web**: HTML with data-role attributes + CSS styling
- **Copy-paste**: Preserves plain ASCII delimiters + content

## See Also
- `/feedback` — Report issues with message differentiation
- `/settings` — Customize colors, borders, styles
- Session respawn proposal — Related UX improvements for session management
