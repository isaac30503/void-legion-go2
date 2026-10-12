# fish completions for void-update (installed in ~/.config/fish/completions/)
complete -c void-update -f
complete -c void-update -s c -l check -d 'Check for updates without root'
complete -c void-update -s l -l list -d 'Show pending updates'
complete -c void-update -s n -l news -d "Void's latest news"
complete -c void-update -s s -l services -d 'Services running old code'
complete -c void-update -l summary -d 'Only the final summary'
complete -c void-update -l tray -d 'The panel icon'
complete -c void-update -l enable -d 'Start at login' -n '__fish_seen_argument -l tray -l check -s c'
complete -c void-update -l disable -d 'Do not start at login' -n '__fish_seen_argument -l tray -l check -s c'
complete -c void-update -l gen-config -d 'Write the configuration file'
complete -c void-update -l show-config -d 'Show the configuration'
complete -c void-update -l edit-config -d 'Edit the configuration'
complete -c void-update -s D -l debug -d 'Show traces'
complete -c void-update -s V -l version -d 'Version'
complete -c void-update -s h -l help -d 'Help'
