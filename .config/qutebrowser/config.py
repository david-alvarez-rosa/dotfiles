c.bindings.default['normal'] = {}
c.input.match_counts = False

config.bind('<Ctrl-f>', 'fake-key <Right>')
config.bind('<Ctrl-b>', 'fake-key <Left>')
config.bind('<Ctrl-a>', 'fake-key <Home>')
config.bind('<Ctrl-e>', 'fake-key <End>')
config.bind('<Ctrl-n>', 'fake-key <Down>')
config.bind('<Ctrl-p>', 'fake-key <Up>')
config.bind('<Alt-f>', 'fake-key <Ctrl-Right>')
config.bind('<Alt-b>', 'fake-key <Ctrl-Left>')
config.bind('<Ctrl-d>', 'fake-key <Delete>')
config.bind('<Alt-d>', 'fake-key <Ctrl-Delete>')
config.bind('<Alt-backspace>', 'fake-key <Ctrl-Backspace>')
config.bind('<Ctrl-w>', 'fake-key <Ctrl-backspace>')
config.bind('<Ctrl-y>', 'insert-text {primary}')

config.bind('<Ctrl-v>', 'scroll-page 0 0.5')
config.bind('<Alt-v>', 'scroll-page 0 -0.5')

config.bind('<Alt-Shift-,>', 'scroll-to-perc 0')
config.bind('<Alt-Shift-.>', 'scroll-to-perc')

config.bind('<Alt-x>', 'set-cmd-text :')
config.bind('<Ctrl-x><Ctrl-c>', 'quit')

ESC_BIND = 'clear-keychain ;; search ;; fullscreen --leave'
config.bind('<Ctrl-g>', ESC_BIND)

config.bind('<Ctrl-h>', 'set-cmd-text -s :help')

config.bind('<Ctrl-Space>', 'mode-enter caret')

config.bind('<Ctrl-x><Ctrl-e>', 'open-editor')

config.bind('<Ctrl-x><Ctrl-v>', 'reload')

config.bind('<Ctrl-+>', 'zoom-in')
config.bind('Ctrl-->', 'zoom-out')

config.bind('<Alt-w>', 'yank')

config.bind('<Ctrl-m>', 'spawn mpv {url}')
config.bind('<Alt-m>', 'hint links spawn mpv {hint-url}')

config.bind('<Ctrl-j>', 'hint all')
config.bind('<Ctrl-Alt-j>', 'hint all tab')

config.bind('<Ctrl-s>', 'set-cmd-text /')
config.bind('<Ctrl-r>', 'set-cmd-text ?')
config.bind('<Alt-n>', 'search-next')
config.bind('<Alt-p>', 'search-prev')

config.bind('<Ctrl-]>', 'tab-next')
config.bind('<Ctrl-[>', 'tab-prev')
config.bind('<Ctrl-Tab>', 'tab-next')
config.bind('<Ctrl-Shift-Tab>', 'tab-prev')

config.bind('<Alt-]>', 'tab-move +')
config.bind('<Alt-[>', 'tab-move -')

config.bind('<Ctrl-x>k', 'tab-close')
config.bind('<Ctrl-x>0', 'tab-close')

config.bind('<Ctrl-x>1', 'tab-only')

config.bind('<Ctrl-/>', 'undo')

config.bind('<Alt-a>', 'back')
config.bind('<Alt-e>', 'forward')

config.bind('<Ctrl-l>', 'set-cmd-text -s :open')
config.bind('<Alt-l>', 'set-cmd-text -s :open -t')
config.bind('<Ctrl-x><Ctrl-f>', 'set-cmd-text -s :open -t')
config.bind('<Ctrl-u><Ctrl-x><Ctrl-f>', 'set-cmd-text -s :open')

c.input.insert_mode.auto_enter = False
c.input.insert_mode.plugins = False

c.input.forward_unbound_keys = 'all'

config.bind('<Ctrl-n>', 'completion-item-focus next', mode='command')
config.bind('<Ctrl-p>', 'completion-item-focus prev', mode='command')

config.bind('<Alt-p>', 'command-history-prev', mode='command')
config.bind('<Alt-n>', 'command-history-next', mode='command')

config.bind('<Ctrl-s>', 'search-next', mode='command')
config.bind('<Ctrl-r>', 'search-prev', mode='command')
config.bind('<Alt-n>', 'search-next', mode='command')
config.bind('<Alt-p>', 'search-prev', mode='command')

config.bind('<Ctrl-g>', 'mode-leave', mode='command')

config.bind('<Ctrl-p>', 'prompt-item-focus prev', mode='prompt')
config.bind('<Ctrl-n>', 'prompt-item-focus next', mode='prompt')
config.bind('<Ctrl-g>', 'mode-leave', mode='prompt')

config.bind('<Ctrl-g>', 'mode-leave', mode='hint')

config.bind('<Alt-w>', 'yank selection', mode='caret')
config.bind('<Ctrl-Space>', 'selection-toggle', mode='caret')
config.bind('<Ctrl-g>', 'mode-leave', mode='caret')

c.editor.command = ['emacsclient', '{}']

config.load_autoconfig(False)

c.tabs.new_position.unrelated = 'next'

c.tabs.wrap = False

c.content.headers.user_agent = 'Mozilla/5.0 (Windows NT 10.0; rv:68.0) Gecko/20100101 Firefox/68.0'

c.completion.height = '45%'

c.completion.scrollbar.padding = 0
c.completion.scrollbar.width = 0

c.tabs.show = 'switching'
c.tabs.show_switching_delay = 3000

c.tabs.title.format = '{perc} {index} {current_title}'

config.source('./themes/minimal/base16-gruvbox-dark-hard.config.py')
