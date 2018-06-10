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
"     * Options is a dictionary that can contain the following:
"       * percentage: The height of the window in percentage of split
"   * send_keys(name, text): Sends 'text' to the pane with the name
"     'name'.  The name is resolved to the pane index value based on the
"     id stored in the pane object.
"   * destroy_pane(name)
"     Kill a pane and remove it from the window list.
"   * delete_destroyed_panes
"     Get rid of internally stored pane data where the pane has been removed
"     elsewhere.  An unfortunate reality of tmux.

function! vimultiplex#main#new()
    let obj = {}
    let obj.panes = {}
    let obj.current_window = vimultiplex#window#new('main')
    call obj.current_window.set_id(vimultiplex#main#_get_current_window())
    let obj.main_pane_id = vimultiplex#main#active_pane_id()

    " let obj.create_pane = function('vimultiplex#main#create_pane')
    function! obj.create_pane(name, options)
        " Because we don't have an event model to know when a pane has been
        " destroyed, I might as well check beforehand rather than just
        " throwing errors at people.
        call self.delete_destroyed_panes()

        if has_key(self.panes, a:name)
            echoerr "vimultiplex#main#create_pane: already a window with name " . a:name
            return
        endif
        if has_key(a:options, 'target')
            let a:options["target_pane"] = self.get_pane_by_name(a:options["target"])
        endif
        let self.panes[a:name] = vimultiplex#pane#new(a:name, a:options)
        let previous_max_pane = vimultiplex#main#newest_pane_id()
        call self.panes[a:name].initialize_pane()
        let post_max_pane = vimultiplex#main#newest_pane_id()
        if previous_max_pane ==# post_max_pane
            " The pane information was gone too long to get stored.
            " This means that the pane was meant to run a command and got
            " blown away as soon as it was done.
            call remove(self.panes, a:name)
        else
            " TODO: Make the pane get this information
            call self.panes[a:name].set_id(post_max_pane)
        endif
    endfunction

    function! obj.send_keys(name, text)
        call self.panes[a:name].send_keys(a:text)
    endfunction

    function! obj.get_pane_by_name(name)
        return self.panes[a:name]
    endfunction

    function! obj.destroy_pane(name)
        if has_key(self.panes, a:name)
            call self.panes[a:name].destroy()
            call remove(self.panes, a:name)
        endif
    endfunction

    function! obj.delete_destroyed_panes()
        for i in keys(self.panes)
            if ( vimultiplex#main#get_pane_index_by_id(self.panes[i].pane_id) ==# -1 )
                call remove(self.panes, i)
            endif
        endfor
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

" vimultiplex#main#active_pane_id()
"
" The current active pane id.  See window#get_pane_data()

function! vimultiplex#main#active_pane_id()
    let pane_data = vimultiplex#window#get_pane_data()
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
    let pane_data = vimultiplex#window#get_pane_data()

    let found_pane = {}
    let max_found_id = ''

    for i in pane_data
        let short_pane_id = i.pane_id
        let short_pane_id = substitute(short_pane_id, '%', '', '')
        if max_found_id ==# '' || short_pane_id + 0 >=# max_found_id + 0
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
    let pane_data = vimultiplex#window#get_pane_data()
    let pane_index = -1

    for i in pane_data
        if i.pane_id ==# a:pane_id
            let pane_index = i.pane_listing
        endif
    endfor

    return pane_index
endfunction
