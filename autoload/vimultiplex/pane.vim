" vimultiplex#pane#new(name, options)
"
" Creates a new pane object, but does not actually create the pane via
" split-window or anything else.  Simply creates a pane object.

function! vimultiplex#pane#new(name, options)
    let obj = {}
    
    " member name: the name of the object, passed in via new
    let obj['name'] = a:name

    " member options: The options for the pane.  Known options at this point
    " include:
    "   * percentage: the percentage width of the new pane.
    "   * target_pane: A pane object that will be split by this pane.  If this
    "   isn't present, then the tmux default will be used (active pane in
    "   active window)
    "   * horizontal: Do a horizontal split.  Vertical is the default.
    "   * command: Run a command in this window.
    let obj['options'] = a:options

    " vimultiplex#pane#initialize_pane()
    "
    " Sends the split_window command based on the pane object settings.

    function! obj.initialize_pane()
        let system_command = ['tmux', 'split-window', '-d']
        if has_key(self.options, 'percentage')
            call add(system_command, '-p')
            call add(system_command, self.options.percentage)
        endif
        if has_key(self.options, 'target_pane')
            let target_pane_index = vimultiplex#main#get_pane_index_by_id(self.options.target_pane.pane_id)
            call add(system_command, '-t')
            call add(system_command, target_pane_index)
            call remove(self.options, 'target_pane')
        endif
        if has_key(self.options, 'horizontal')
            call add(system_command, '-h')
        endif
        if has_key(self.options, 'command')
            call add(system_command, '"' . escape(self.options.command, '\"$`') . '"')
        endif
        call system(join(system_command, ' '))
    endfunction

    " vimultiplex#pane#set_id(id)
    "
    " Sets the objects pane_id value.  Can be set using
    " vimultiplex#main#newest_pane_id().  In fact, a superior design might be
    " going back and telling this object to grab it directly during
    " initialize_pane. (TODO)

    function! obj.set_id(id)
        let self.pane_id = a:id
    endfunction

    " vimultiplex#pane#send_keys(text)
    "
    " Send keys to the pane defined by this object.

    function! obj.send_keys(text)
        " The following escape command is taken from
        " https://github.com/benmills/vimux.
        " See vimux for an alternative to vimultiplex.
        call system("tmux send-keys -t " . vimultiplex#main#get_pane_index_by_id(self.pane_id) . ' "' . escape(a:text,'\"$`') . '"')
    endfunction

    " function destroy()
    "
    " Kill this pane in tmux.
    function! obj.destroy()
        call system("tmux kill-pane -t " . vimultiplex#main#get_pane_index_by_id(self.pane_id))
    endfunction

    " function external()
    "
    " Return true if this pane was not created by vimultiplex, known via the
    " 'preinitialized' setting.
    function! obj.external()
        return exists("self.settings['preinitialized']") && self.settings.preinitialized
    endfunction

    return obj
endf
