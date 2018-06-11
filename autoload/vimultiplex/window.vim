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
"   * create_pane(name, options): Creates a pane based on the passed options.
"     See pane.vim for an options list.
"   * update_pane_listing: For each pane in this window, if the window
"     controller doesn't know about it, add a stub listing for it in the panes
"     dictionary.
"   * has_pane: Check to see if a pane is known about in the panes dictionary.
"   * has_named_pane: has a pane with the proper name, created by vimultiplex
"     method calls.
"   * send_keys: Send keys to a given pane in this window.
"   * destroy_pane: kill a pane and delete it from the pane data for this
"   window.

function! vimultiplex#window#new(name, settings)
    let obj = {}
    let obj.panes = {}
    let obj.name = a:name
    let obj.settings = a:settings

    function! obj.initialize()
        if self.settings.preinitialized || self.settings.initialized
            echoerr "Could not initialize pre-initialized window: " . self.name
        endif
        let system_command = ['tmux', 'new-window', '-d']
        call system(join(system_command), ' '))
        self['initialized'] = 1
    endfunction

    " TODO: Cause create pane to actually care about the current window.
    function! obj.create_pane(name, options)
        " Because we don't have an event model to know when a pane has been
        " destroyed, I might as well check beforehand rather than just
        " throwing errors at people.
        call self.delete_destroyed_panes()

        if self.has_named_pane(a:name)
            echoerr "vimultiplex#window#create_pane: already a window with name " . a:name
            return
        endif

        if has_key(a:options, 'target')
            let a:options["target_pane"] = self.get_pane_by_name(a:options["target"])
        endif

        let self.panes[a:name] = vimultiplex#pane#new(a:name, a:options)
        let previous_max_pane = vimultiplex#window#newest_pane_id(self.window_id)
        call self.panes[a:name].initialize_pane()
        let post_max_pane = vimultiplex#window#newest_pane_id(self.window_id)

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

    function! obj.has_named_pane(pane_name)
        return has_key(self.panes, a:pane_name)
    endfunction

    function! obj.get_pane_by_name(name)
        return self.panes[a:name]
    endfunction

    function! obj.destroy_pane(name)
        if self.has_named_pane(a:name)
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
        call extend(command_data, ['-t', a:1])
    endif
    let pane_data = split(system(join(command_data, ' ')), "\n")
    let parsed_pane_data = []
    for i in pane_data
        let current_pane_data = matchlist(i, '\v^(\d+): \[(\d+x\d+)\] \[[^\]]+\] (\%\d+) ?\(?(active)?\)?')
        call add(parsed_pane_data, { 'pane_listing': current_pane_data[1], 'pane_id': current_pane_data[3], 'active': current_pane_data[4]} )
    endfor
    return parsed_pane_data
endfunction

" vimultiplex#window#newest_pane_id()
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

function! vimultiplex#window#newest_pane_id(...)
    let current_window = ''
    if a:0 ># 0
        let current_window = a:1
    else
        let current_window = vimultiplex#main#_get_current_window()
    endif

    let pane_data = vimultiplex#window#get_pane_data(current_window)

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
