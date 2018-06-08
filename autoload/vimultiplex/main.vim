let g:vimultiplex_main = {}

" vimultiplex#main#new
"
" Creates a new vimultiplex window controller.
"
" A window controller contains the following member data:
"   * panes: A dictionary containing the panes created by vimultiplex
"     * For more details, see vimultiplex#pane
"   * current_window: The current window id
"   * main_pane_id: The pane id for the pane that vim is running in.
"
" A window controller contains the following methods:
"   * create_pane(name, options):
"     Creates a new pane and adds an entry to the panes dictionary with
"     the key 'name'.
"   * send_keys(name, text): Sends 'text' to the pane with the name
"     'name'.  The name is resolved to the pane index value based on the
"     id stored in the pane object.
"   * Options is a dictionary that can contain the following:
"     * percentage: The height of the window in percentage of split

function! vimultiplex#main#new()
    let obj = {}
    let obj.panes = {}
    let obj.current_window = vimultiplex#main#_get_current_window()

    let obj.main_pane_id = vimultiplex#main#active_pane_id()

    " let obj.create_pane = function('vimultiplex#main#create_pane')
    function! obj.create_pane(name, options)
        let self.panes[a:name] = vimultiplex#pane#new(a:name, a:options)
        call self.panes[a:name].initialize_pane()
        call self.panes[a:name].set_id(vimultiplex#main#newest_pane_id())
    endfunction

    function! obj.send_keys(name, text)
        call self.panes[a:name].send_keys(a:text)
    endfunction

    return obj
endfunction

" Static methods of this vimultiplex.

" vimultiplex#main#_get_current_window()
"
" Get the current window id.

function! vimultiplex#main#_get_current_window()
    return substitute(system("tmux display-message -p '#{window_id}'"),'\n\+$','','')
endfunction

" vimultiplex#main#start()
"
" Initializes the global object g:vimultiplex_main as a new vimultiplex window
" controller.

function! vimultiplex#main#start()
    let g:vimultiplex_main = vimultiplex#main#new()
endfunction

" vimultiplex#main#get_pane_data()
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

function! vimultiplex#main#get_pane_data()
    let pane_data = split(system("tmux list-panes"), "\n")
    let parsed_pane_data = []
    for i in pane_data
        let current_pane_data = matchlist(i, '\v^(\d+): \[(\d+x\d+)\] \[[^\]]+\] (\%\d+) ?\(?(active)?\)?')
        call add(parsed_pane_data, { 'pane_listing': current_pane_data[1], 'pane_id': current_pane_data[3], 'active': current_pane_data[4]} )
    endfor
    return parsed_pane_data
endfunction

" vimultiplex#main#active_pane_id()
"
" The current active pane id.  See get_pane_data()

function! vimultiplex#main#active_pane_id()
    let pane_data = vimultiplex#main#get_pane_data()
    let pane_id = ''

    for i in pane_data
        if i.active ==# 'active'
            let pane_id = i.pane_id
        endif
    endfor

    return pane_id
endfunction

" vimultiplex#main#newest_pane_id()
"
" The newest pane that has been created.  I have no idea if the system starts
" rotating through panes at some point, but what I do know is that the indexes
" at the beginning of the line when running tmux list-panes is not associated
" with how recently the pane was created.  Instead, it is the pane id that
" increments up at all times, while the id at the beginning is based on the
" pane position.
"
" By keeping the pane id, and using it to later get the index id, I can always
" send information to a pane based on that id, and even name that pane, as
" I've done in this code.

function! vimultiplex#main#newest_pane_id()
    let pane_data = vimultiplex#main#get_pane_data()

    let found_pane = {}
    let max_found_id = ''

    for i in pane_data
        let short_pane_id = i.pane_id
        let short_pane_id = substitute(short_pane_id, '%', '', '')
        if max_found_id ==# '' || short_pane_id >=# max_found_id
            let found_pane = i
            let max_found_id = short_pane_id
        endif
    endfor

    return found_pane.pane_id
endfunction

" vimultiplex#main#get_pane_index_by_id(pane_id)
"
" Get the pane index (the first number listed in tmux list-panes) based on the
" pane id (the last number listed in tmux list-panes).

function! vimultiplex#main#get_pane_index_by_id(pane_id)
    let pane_data = vimultiplex#main#get_pane_data()
    let pane_index = -1

    for i in pane_data
        if i.pane_id ==# a:pane_id
            let pane_index = i.pane_listing
        endif
    endfor

    return pane_index
endfunction
