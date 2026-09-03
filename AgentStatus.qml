import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// One chip per open coding-agent session, read off the terminal title each
// agent writes. Claude Code writes "◐ <session>" while it works and
// "✳ <session>" once it is done; Codex is asked (via ~/.codex/config.toml,
// [tui] terminal_title) for "<Run state> | <thread title> | <project>". The
// chip carries the vendor's own mark, a spinning arc while the agent thinks
// and a pulse the moment the answer is ready.
BarWidget {
  id: root
  moduleName: "io.github.mae240.agent-status"

  // Moon frames Claude cycles through while working, braille frames Codex uses
  // when its title carries no run state. Anything from the ready set means the
  // agent is done; Claude writes a leading "!" when it needs a decision.
  readonly property string claudeBusyGlyphs: "◐◓◑◒◴◵◶◷"
  readonly property string codexBusyGlyphs: "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏⠍⠌⠓⠒⠆⠖⠶"
  readonly property string readyGlyphs: "✳✻✽✶✢❋⁕*·⏺"

  // Codex run-state words, as they land in the first title segment. Unknown
  // words count as work in progress rather than being dropped, so a state from
  // a future Codex release still shows up as a session.
  readonly property var codexReady: ["Ready", "Idle", "Done"]
  readonly property var codexAttention: ["Waiting", "Blocked", "Approval"]

  // Titles are only read from windows an agent can live in: everything
  // omarchy-launch-tui opens carries an org.omarchy.* app id, and a
  // hand-started session sits in one of the terminals Omarchy ships. Without
  // that, any window titled "Inbox | Mail" would look like a Codex session.
  readonly property var terminalAppIds: ["foot", "footclient", "alacritty",
    "com.mitchellh.ghostty", "kitty", "org.wezfurlong.wezterm"]

  readonly property int maxLabelWidth: Number(setting("maxWidth", 180))
  readonly property int maxSessions: Number(setting("maxSessions", 4))
  readonly property color doneColor: colorSetting("doneColor", "#4ade80")
  readonly property color attentionColor: colorSetting("attentionColor", Color.urgent)
  readonly property color claudeColor: colorSetting("claudeColor", "#d97757")
  readonly property color codexColor: colorSetting("codexColor", textColor)

  readonly property color textColor: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string textFont: root.bar ? root.bar.fontFamily : Style.font.family

  // The bar anchors its center section to the middle of the screen, so a left
  // section that keeps growing ends up drawn over the clock. Past the cap the
  // remaining sessions are counted in one "+n" chip instead.
  readonly property var sessionWindows: {
    var list = []
    var items = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
    for (var i = 0; i < items.length; i++) {
      if (items[i] && sessionFor(items[i].title, items[i].appId)) list.push(items[i])
    }
    return list
  }
  readonly property int shownSessions: maxSessions > 0
    ? Math.min(sessionWindows.length, maxSessions) : sessionWindows.length
  readonly property int hiddenSessions: sessionWindows.length - shownSessions

  readonly property real markSize: Style.font.body
  readonly property real ringSize: Math.min(markSize * 1.9,
    Math.max(markSize + Style.space(4), root.barSize - Style.space(10)))

  // The chips also share a width budget, because four long session names reach
  // the clock on their own. Names are elided at an equal share of it, down to
  // a width that still shows the first word or two.
  readonly property real widthBudget: Math.max(240, Screen.width * 0.28)
  readonly property real chipChrome: ringSize + Style.space(7) * 2
    + Style.space(4) * 2 + Style.font.caption
  readonly property int labelWidth: {
    var budget = widthBudget - (hiddenSessions > 0 ? chipChrome : 0)
    var share = budget / Math.max(1, shownSessions) - chipChrome
    return Math.max(56, Math.min(maxLabelWidth, Math.round(share)))
  }

  // A cleared color arrives as an empty string, which is not a color, so it
  // can only mean "keep the default".
  function colorSetting(name, fallback) {
    var value = String(setting(name, "") || "").trim()
    return value === "" ? fallback : value
  }

  function isTerminal(appId) {
    var id = String(appId || "").toLowerCase()
    return id.indexOf("org.omarchy.") === 0 || terminalAppIds.indexOf(id) >= 0
  }

  function isThreadId(value) {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
  }

  function sessionFor(title, appId) {
    if (!title || !isTerminal(appId)) return null

    // Codex, configured: "<Run state> | <thread title> | <project>".
    var runState = /^([A-Z][a-z]+)\s+\|\s+(.+)$/.exec(title)
    if (runState) {
      var word = runState[1]
      var state = codexReady.indexOf(word) >= 0 ? "ready"
        : codexAttention.indexOf(word) >= 0 ? "attention" : "busy"
      // Remaining segments are thread title and project, in the order
      // config.toml lists them. Codex shows the raw thread id until it has
      // named the thread, which is noise in a chip, so drop it.
      var parts = runState[2].split(/\s+\|\s+/)
        .map(function (part) { return part.trim() })
        .filter(function (part) { return part !== "" && !isThreadId(part) })
      return {
        agent: "codex",
        state: state,
        detail: word,
        name: parts.length > 0 ? parts[0] : "Codex",
        context: parts.slice(1).join(" · ")
      }
    }

    if (title.length < 3 || title.charAt(1) !== " ") return null
    var glyph = title.charAt(0)
    var name = title.slice(2).trim()
    if (name === "") return null
    if (claudeBusyGlyphs.indexOf(glyph) >= 0)
      return { agent: "claude", state: "busy", detail: "working…", name: name, context: "" }
    if (readyGlyphs.indexOf(glyph) >= 0)
      return { agent: "claude", state: "ready", detail: "done", name: name, context: "" }
    if (glyph === "!")
      return { agent: "claude", state: "attention", detail: "needs you", name: name, context: "" }
    // Codex, unconfigured: braille spinner and no state word to fall back on,
    // so it can only ever be reported as busy.
    if (codexBusyGlyphs.indexOf(glyph) >= 0)
      return { agent: "codex", state: "busy", detail: "working…", name: name, context: "" }
    return null
  }

  function hiddenSessionNames() {
    var names = []
    for (var i = shownSessions; i < sessionWindows.length; i++) {
      var session = sessionFor(sessionWindows[i].title, sessionWindows[i].appId)
      if (session) names.push(session.name)
    }
    return names.join(" · ")
  }

  // Row skips invisible delegates, so its implicitWidth is 0 with no sessions.
  visible: !vertical && chipRow.implicitWidth > 0
  implicitWidth: visible ? chipRow.implicitWidth + Style.space(6) * 2 : 0
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Row {
    id: chipRow
    anchors.verticalCenter: parent.verticalCenter
    x: Style.space(6)
    spacing: Style.space(4)

    Repeater {
      model: ToplevelManager.toplevels

      delegate: Item {
        id: slot

        required property var modelData
        readonly property var session: root.sessionFor(modelData ? modelData.title : "",
          modelData ? modelData.appId : "")
        readonly property bool isSession: session !== null
        readonly property string agentState: isSession ? session.state : "busy"
        readonly property bool busy: agentState === "busy"
        readonly property string agent: isSession ? session.agent : "claude"
        readonly property color agentColor: agent === "codex" ? root.codexColor : root.claudeColor
        readonly property color agentStateColor: agentState === "ready" ? root.doneColor
          : agentState === "attention" ? root.attentionColor : agentColor
        property bool ready: false

        visible: isSession && root.sessionWindows.indexOf(modelData) < root.shownSessions
        width: chip.width
        height: root.barSize

        onAgentStateChanged: {
          if (!isSession) return
          if (agentState === "ready" && ready) donePulse.restart()
          // The spinner stops wherever it happens to be, and the idle ring
          // would keep that tilt.
          spinner.rotation = 0
        }
        Component.onCompleted: ready = true

        Rectangle {
          id: chip
          anchors.verticalCenter: parent.verticalCenter
          width: chipContent.width + Style.space(7) * 2
          height: Math.min(root.barSize - Style.space(4), chipContent.height + Style.space(4) * 2)
          radius: height / 2
          color: Util.alpha(slot.agentStateColor, slot.busy ? 0.06 : 0.09)
          border.width: 1
          border.color: Util.alpha(slot.agentStateColor, slot.busy ? 0.18 : 0.3)

          Behavior on color { ColorAnimation { duration: 250 } }
          Behavior on border.color { ColorAnimation { duration: 250 } }

          // Accent flash layered on top so the base colors stay declarative.
          Rectangle {
            id: doneFlash
            anchors.fill: parent
            radius: parent.radius
            color: Util.alpha(root.doneColor, 0.35)
            opacity: 0
          }

          Row {
            id: chipContent
            anchors.centerIn: parent
            spacing: Style.space(4)

            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: root.ringSize
              height: root.ringSize

              Shape {
                id: spinner
                anchors.fill: parent
                antialiasing: true
                layer.enabled: true
                layer.samples: 4
                transformOrigin: Item.Center
                opacity: slot.busy ? 1.0 : 0.55

                Behavior on opacity { NumberAnimation { duration: 250 } }

                ShapePath {
                  strokeColor: slot.agentStateColor
                  strokeWidth: Math.max(1, Math.round(root.ringSize / 12))
                  fillColor: "transparent"
                  capStyle: ShapePath.RoundCap

                  PathAngleArc {
                    centerX: root.ringSize / 2
                    centerY: root.ringSize / 2
                    radiusX: (root.ringSize - Math.max(1, Math.round(root.ringSize / 12))) / 2
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: slot.busy ? 100 : 360

                    Behavior on sweepAngle {
                      NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                    }
                  }
                }

                NumberAnimation on rotation {
                  running: slot.busy && slot.visible
                  from: 0
                  to: 360
                  duration: 1100
                  loops: Animation.Infinite
                }

                // Attention is the one state that has to catch the eye without
                // a spinner, so the ring breathes instead of turning.
                SequentialAnimation on opacity {
                  running: slot.agentState === "attention" && slot.visible
                  loops: Animation.Infinite
                  NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                  NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
                }
              }

              AgentMark {
                anchors.centerIn: parent
                agent: slot.agent
                // The sunburst reads smaller than the solid OpenAI knot at the
                // same box size, so it gets a touch more room.
                iconSize: root.markSize * (slot.agent === "codex" ? 0.92 : 1.06)
                color: slot.agentColor
                opacity: slot.busy ? 0.8 : 1.0

                Behavior on opacity { NumberAnimation { duration: 250 } }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, root.labelWidth)
              text: slot.isSession ? slot.session.name : ""
              color: root.textColor
              font.family: root.textFont
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              opacity: slot.busy ? 0.7 : 1.0

              Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: !slot.busy
              text: slot.agentState === "attention" ? "!" : "✓"
              color: slot.agentStateColor
              font.family: root.textFont
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          SequentialAnimation {
            id: donePulse
            loops: 2

            ParallelAnimation {
              NumberAnimation {
                target: chip
                property: "scale"
                from: 1.0
                to: 1.08
                duration: 140
                easing.type: Easing.OutQuad
              }
              NumberAnimation {
                target: doneFlash
                property: "opacity"
                from: 0
                to: 1
                duration: 140
              }
            }
            ParallelAnimation {
              NumberAnimation {
                target: chip
                property: "scale"
                to: 1.0
                duration: 260
                easing.type: Easing.InOutQuad
              }
              NumberAnimation {
                target: doneFlash
                property: "opacity"
                to: 0
                duration: 260
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (slot.modelData) slot.modelData.activate()
            onEntered: if (root.bar) root.bar.showTooltip(root,
              slot.isSession
                ? (slot.agent === "codex" ? "Codex" : "Claude Code")
                  + " · " + slot.session.name
                  + (slot.session.context ? " · " + slot.session.context : "")
                  + " · " + slot.session.detail
                : "")
            onExited: if (root.bar) root.bar.hideTooltip(root)
          }
        }
      }
    }

    // Everything past maxSessions, so a burst of sessions cannot push the
    // left section of the bar over the clock.
    Item {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.hiddenSessions > 0
      width: overflowChip.width
      height: root.barSize

      Rectangle {
        id: overflowChip
        anchors.verticalCenter: parent.verticalCenter
        width: overflowLabel.implicitWidth + Style.space(7) * 2
        height: Math.min(root.barSize - Style.space(4),
          overflowLabel.implicitHeight + Style.space(4) * 2)
        radius: height / 2
        color: Util.alpha(root.textColor, 0.06)
        border.width: 1
        border.color: Util.alpha(root.textColor, 0.18)

        Text {
          id: overflowLabel
          anchors.centerIn: parent
          text: "+" + root.hiddenSessions
          color: root.textColor
          font.family: root.textFont
          font.pixelSize: Style.font.caption
          opacity: 0.7
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: if (root.bar) root.bar.showTooltip(root, root.hiddenSessionNames())
          onExited: if (root.bar) root.bar.hideTooltip(root)
        }
      }
    }
  }
}
