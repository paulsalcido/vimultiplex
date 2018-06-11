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
"     Creates a pane for the current (main) window.
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
        call self.current_window.create_pane(a:name, a:options)
    endfunction

    function! obj.send_keys(name, text)
        call self.current_window.send_keys(a:name, a:text)
    endfunction

    function! obj.get_pane_by_name(name)
        return self.current_window.get_pane_by_name(a:name)
    endfunction

    function! obj.destroy_pane(name)
        if has_key(self.panes, a:name)
            call self.panes[a:name].destroy()
            call remove(self.panes, a:name)
        endif
    endfunction

    function! obj.delete_destroyed_panes()
        call self.current_window.delete_destroyed_panes()
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
