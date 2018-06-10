" vimultiplex#window#new
"
" Creates a new window management object.
"
" A window controller contains the following member data:
"   * panes: A dictionary of panes for this window.
"   * name: The name of this window, applied by this code.  it ignores the
"     name that the system has.
"
" A window controller contains the following methods:
"   * initialize: Create the window specified by the object.
"   * set_id: Set the window id for this controller, as represented in the
"     tmux system itself.
"   * update_pane_listing: For each pane in this window, if the window
"     controller doesn't know about it, add a stub listing for it in the panes
"     dictionary.
"   * has_pane: Check to see if a pane is known about in the panes dictionary.

function! vimultiplex#window#new(name)
    let obj = {}
    let obj.panes = {}
    let obj.name = a:name

    function! obj.initialize()
        let system_command = ['tmux', 'new-window', '-id']
        call system(join(system_command), ' '))
    endfunction

    function! obj.set_id(new_id)
        let self.window_id = a:new_id
    endfunction

    function! obj.update_pane_listing()
        let pane_data = vimultiplex#window#get_pane_data(self.window_id)
        for i in pane_data
            if ! self.has_pane(i.pane_id)
                self.panes[i.pane_id] = vimultiplex#pane#new(i.pane_id, {})
                self.panes[i.pane_id].set_id(i.pane_id)
            endif
        endfor
    endfunction

    function! obj.has_pane(pane_id)
        for k in keys(self.panes)
            if self.panes[k].pane_id == a:pane_id
                return 1
            endif
        endfor
        return 0
    endfunction

    return obj
endfunction

" vimultiplex#window#get_pane_data()
"
" Returns some information about all the panes for the current window.  This
" command has multiple uses and several assumptions are made.
"
" This calls the command
"     tmux list-panes
" and parses the lines produced, returning them as an array of dictionaries
" containing some structured data about the returned lines:
"
" {
"   'pane_listing': (the number at the beginning of the line)
"   'pane_id': (the id listed later in the line)
"   'active': (whether or not this is the active pane)
" }
"
" This dictionary will contain more information as I need it.

function! vimultiplex#window#get_pane_data(...)
    let command_data = ['tmux', 'list-panes']
    if a:0 ># 0
        call add(command_data, '-t', a:1)
    endif
    let pane_data = split(system(join(command_data, ' ')), "\n")
    let parsed_pane_data = []
    for i in pane_data
        let current_pane_data = matchlist(i, '\v^(\d+): \[(\d+x\d+)\] \[[^\]]+\] (\%\d+) ?\(?(active)?\)?')
        call add(parsed_pane_data, { 'pane_listing': current_pane_data[1], 'pane_id': current_pane_data[3], 'active': current_pane_data[4]} )
    endfor
    return parsed_pane_data
endfunction

