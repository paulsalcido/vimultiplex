" vimultiplex#pane#new(name)
"
" Creates a new pane object, but does not actually create the pane via
" split-window or anything else.  Simply creates a pane object.
"
" Members data of this object:
"   * name: the name passed when created.
"   * pane_id: can be set with set_id, after the pane is initialized
"
" Methods of this object:
"   * initialize_pane: actually create the pane
"     This should actually be called by the parent class, wouldn't recommend
"     that you do so directly.
"   * set_id: set the id of the pane.
"   * send_keys(text): send keys to the pane referenced by this class.

function! vimultiplex#pane#new(name)
    let obj = {}
    let obj['name'] = a:name

    " vimultiplex#pane#initialize_pane()
    "
    " Sends the split_window command based on the pane object settings.

    function! obj.initialize_pane()
        call system("tmux split-window -d")
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

    return obj
endf
