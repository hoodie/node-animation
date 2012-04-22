{ EventEmitter } = require 'events'
{requestAnimationFrame,cancelAnimationFrame} = require 'request-animation-frame'
ms = require 'ms'

now = Date.now ? -> new Date().getTime()


# FIXME larger executiontime for timeouts?


class @Animation extends EventEmitter

    constructor: (opts = {}) ->
        # options
        @timoutexecutiontime = ms(opts.timeoutexecution ? 20)
        @executiontime = ms(opts.execution ? 5)
        @timeouttime =  opts.timeout
        @timeouttime = ms(@timeouttime) if @timeouttime?
        @autotoggle = opts.toggle ? no
        @frametime = opts.frame
        @frametime = ms(@frametime) if @frametime?
        # values
        @queue = []
        # states
        @running = no
        @paused = no
        super

    work_queue: (started, dt, executiontime) ->
        t = now()
        while @queue.length and t - started < executiontime
            (@queue.shift())?(dt) # execute
            t = now()

    push: (callback) ->
        @queue.push(callback)
        @resume() if @running and @autotoggle

    nextTick: (callback) =>
        [timeout, request] = [null, null]
        t = now()
        tick = (success) ->
            # calc delta time
            started = now()
            dt = started - t
            if success
                executiontime = @executiontime
            else
                executiontime = @timoutexecutiontime
            # break other timeout
            if success
                clearTimeout(timeout)
            else # skip the requested AnimationFrame when it gets called
                cancelAnimationFrame(request)
            # work
            @emit('tick', dt)
            callback?(dt)
            @work_queue(started, dt, executiontime)
            # if animation is running and not paused, keep it running
            #  or pause it if autotoggle is enabled
            if @running and not @paused
                if @queue.length
                    @nextTick()
                else # decide if animation can pause
                    if @autotoggle
                        @pause()
                    else # keep running
                        @nextTick()
        # send the request
        request = requestAnimationFrame(tick.bind(this, yes), @frametime)
        if @timeouttime?
            timeout = setTimeout(tick.bind(this, no), @timeouttime)

    # switches

    start: () ->
        return if @running
        @running = yes
        @emit 'start'
        unless @paused
            if @autotoggle
                if @queue.length
                    @nextTick()
                else
                    @pause()
            else
                @nextTick()

    stop: () ->
        return unless @running
        @running = no
        @emit 'stop'

    pause: () ->
        return if @paused
        @paused = yes
        @emit 'pause'

    resume: () ->
        return unless @paused
        @paused = no
        @emit 'resume'
        @nextTick() if @running and (not @autotoggle or @queue.length is 1)

