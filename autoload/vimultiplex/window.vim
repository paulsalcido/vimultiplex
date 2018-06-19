" vimultiplex#window#new
"
" Creates a new window management object.

function! vimultiplex#window#new(name, options)
    let obj = {}

    " member panes: A dictionary containing all of the panes in the current window.
    let obj.panes = {}

    " name: The name of this window.
    let obj.name = a:name

    " options: Options passed to 'new' for this class object.
    let obj.options = a:options

    " function initialize()
    "
    " If this isn't a preinitialized or already initialized window, run the
    " commands necessary to create the new window.
    "
    " Creates the window with the -d flag, so it won't immediately switch over
    " to the new window.
    function! obj.initialize()
        if self.initialized()
            echoerr "Could not initialize pre-initialized window: " . self.name
        endif
        let system_command = ['tmux', 'new-window', '-d']
        call system(join(system_command), ' ')
        let self.options['initialized'] = 1
    endfunction

    " function initialized
    "
    " If this window is already created, either by having been initialized or
    " because it it preinitialized, this will return true.
    function! obj.initialized()
        for i in [ 'initialized', 'preinitialized' ]
            if exists('self.options[i]') && self.options[i]
                return 1
            endif
        endfor
        return 0
    endfunction

    " function create_pane(name, options)
    "
    " This method creates a pane within this current window.
    "
    " The options dictionary might contain the following:
    "   * target: name of a target pane.  If not passed, then the target pane
    "   will be the active pane for this window, as all windows have an
    "   officially active pane.
    function! obj.create_pane(name, options)
        " Because we don't have an event model to know when a pane has been
        " destroyed, I might as well check beforehand rather than just
        " throwing errors at people.
        call self.delete_destroyed_panes()

        if self.has_named_pane(a:name)
            echoerr "vimultiplex#window#create_pane: already a window with name " . a:name
            return
        endif

        " Here we try to get a pane target to get this to start within this
        " window.
        " 
        " TODO: Break if requested target is not part of this window.
        if has_key(a:options, 'target')
            let a:options["target_pane"] = self.get_pane_by_name(a:options["target"])
        else
            " Choose the current active pane for this window.
            let a:options["target_pane"] = self.panes[self.get_pane_name(vimultiplex#main#active_pane_id(self.window_id))]
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

    " function setup_default_pane(name)
    "
    " Find the initially created pane when this window was created, and make
    " it the default pane for the current window, with the name passed.  Set
    " up wth 'preinitialized': 1
    function! obj.setup_default_pane(name, options)
        let known_panes = vimultiplex#window#get_pane_data(self.window_id)

        if len(known_panes) ==# 1
            let self.panes[a:name] = vimultiplex#pane#new(a:name, a:options)
            call self.panes[a:name].set_id(known_panes[0].pane_id)
        endif
    endfunction

    " function send_keys(name, text)
    "
    " Sends 'text' with send-keys to the pane specified by 'name'.
    function! obj.send_keys(name, text)
        call self.panes[a:name].send_keys(a:text)
    endfunction

    " function set_id
    "
    " Set the id of the current window.
    function! obj.set_id(new_id)
        let self.window_id = a:new_id
    endfunction

    " function update_pane_listing()
    "
    " Add panes to the panes object that were created outside of vimultiplex.
    " Any pane created this way will not be destroyed by vimultiplex when
    " destroy_all is called.
    function! obj.update_pane_listing()
        let pane_data = vimultiplex#window#get_pane_data(self.window_id)
        for i in pane_data
            if ! self.has_pane(i.pane_id)
                let self.panes[i.pane_id] = vimultiplex#pane#new(i.pane_id, { 'preinitialized': 1 })
                call self.panes[i.pane_id].set_id(i.pane_id)
            endif
        endfor
    endfunction

    " function has_pane(pane_id)
    "
    " If this window has a pane with the id passed, this returns true (1).
    function! obj.has_pane(pane_id)
        for k in keys(self.panes)
            if self.panes[k].pane_id ==# a:pane_id
                return 1
            endif
        endfor
        return 0
    endfunction

    " function has_named_pane(pane_name)
    "
    " Returns true (1) if this window object has a pane with the given name.
    function! obj.has_named_pane(pane_name)
        return has_key(self.panes, a:pane_name)
    endfunction

    " function get_pane_by_name(name)
    "
    " Returns the pane object represented by the given name.
    function! obj.get_pane_by_name(name)
        return self.panes[a:name]
    endfunction

    " function get_pane_name(pane_id)
    "
    " Get the name of a pane given the pane_id.  Returns an empty string ('')
    " if the pane is not found for this window.
    function! obj.get_pane_name(pane_id)
        call self.update_pane_listing()

        for i in keys(self.panes)
            if self.panes[i].pane_id ==# a:pane_id
                return i
            endif
        endfor

        return ''
    endfunction

    " function destroy_all()
    "
    " Gets rid of all panes that were created by vimultiplex in this window.
    " If all panes are destroyed, then the vimultiplex window goes away.  If
    " this is called from the main object via destroy_all, then this window
    " object is also destroyed, regardless if all panes are destroyed or not.
    function! obj.destroy_all()
        for i in keys(self.panes)
            if ! self.panes[i].external()
                call self.panes[i].destroy()
                call remove(self.panes, i)
            endif
        endfor
    endfunction

    " function destroy_pane(name)
    "
    " This will tell a pane to kill itself and go away, regardless of whether
    " or not it was created by vimultiplex.
    function! obj.destroy_pane(name)
        if self.has_named_pane(a:name)
            call self.panes[a:name].destroy()
            call remove(self.panes, a:name)
        endif
    endfunction

    " function delete_destroyed_panes()
    "
    " For every pane known by vimultiplex, check to see if it still exists.
    " If not, delete it from the window object pane dictionary.
    function! obj.delete_destroyed_panes()
        for i in keys(self.panes)
            if vimultiplex#main#get_pane_index_by_id(self.panes[i].pane_id) ==# -1
                call remove(self.panes, i)
            endif
        endfor
    endfunction

    return obj
endfunction

" vimultiplex#window#newest_window_id()
"
" Get the newest window id.

function! vimultiplex#window#newest_window_id()
    let window_data = vimultiplex#window#get_window_data()

    let found_window = {}
    let max_found_id = ''

    for i in window_data
        let short_window_id = i.window_id
        let short_window_id = substitute(short_window_id, '@', '', '')
        if max_found_id ==# '' || short_window_id + 0 >=# max_found_id + 0
            let found_window = i
            let max_found_id = short_window_id
        endif
    endfor

    return found_window.window_id
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
    let command_data = ['tmux', 'list-panes', '-F', "'#{window_index}.#{pane_index} #{pane_id} #{pane_active}'"]
    if a:0 ># 0
        call extend(command_data, ['-t', a:1])
    else
        call extend(command_data, ['-a'])
    endif
    let pane_data = split(system(join(command_data, ' ')), "\n")
    let parsed_pane_data = []
    for i in pane_data
        let current_pane_data = matchlist(i, '\v^((\d+)\.\d+) (\%\d+) (\d)')
        call add(parsed_pane_data, { 'pane_index': current_pane_data[1], 'window_id': current_pane_data[2], 'pane_id': current_pane_data[3], 'active': current_pane_data[4]} )
    endfor
    return parsed_pane_data
endfunction

" vimultiplex#window@get_window_data()
"
" Returns some information about all of the current windows in tmux.
"
" Currently I'm working with the following output style:
"
" 0: vim- (1 panes) [271x60] [layout b0dd,271x60,0,0,0] @0
" 2: bash* (1 panes) [271x60] [layout b0df,271x60,0,0,2] @2 (active)
"
" The '@2' number will be the internal id, and the '2' is the index of the
" window, which is typically used when sending commands.

function! vimultiplex#window#get_window_data()
    let command_data = ['tmux', 'list-windows', '-F', "'#{window_index} #{window_id} #{window_active} #{window_name}'"]

    let window_data = split(system(join(command_data, ' ')), "\n")
    let parsed_window_data = []
    for i in window_data
        let current_window_data = matchlist(i, '\v^(\d+) (\@\d+) (\d+) (.*)$')
        call add(parsed_window_data, {'window_index': current_window_data[1], 'window_name': current_window_data[4], 'window_id': current_window_data[2], 'active': current_window_data[3], })
    endfor

    return parsed_window_data
endfunction

" vimultiplex#window#get_window_index_by_id(window_id)
"
" Returns a window index based on the window id.

function! vimultiplex#window#get_window_index_by_id(window_id)
    let window_data = vimultiplex#window#get_window_data()

    for i in window_data
        if i.window_id ==# a:window_id
            return i.window_index
        endif
    endfor

    return ''
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
        let current_window = vimultiplex#main#get_current_window()
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
