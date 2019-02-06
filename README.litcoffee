
![PlayFrame](https://avatars3.githubusercontent.com/u/47147479)
# PromiSync

###### 0.7 kB Promises that Sync as you prefer

## Installation
```sh
npm install --save @playframe/promisync
```

## Description
PromiSync will create a
[Promise engine](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)
on top of any scheduling implementation.
So you get to decide when your `then`, `catch` and `finally`
handlers are going to execute and if
`try` `catch` wrap is required.
By buidling PromiSync on top of
[OverSync](https://github.com/playframe/oversync)
we get a Promise implemetation with frame rendering engine
under the hood.

Should work well mixed with any other Promise implementation or
`await` syntax.
Please submit issues if any found


## Usage
```js
const oversync = require('@playframe/oversync')
const promisync = require('@playframe/promisync')
// let's add `decrypt` and `encrypt` stages to standard flow
const sync = oversync(performance.now, requestAnimationFrame,
  ['next', 'decrypt', 'catch', 'then', 'finally', 'encrypt', 'render'])

const CryptoPromiSync = promisync(sync)

CryptoPromiSync.Promise
  .resolve(secret)
  .decrypt(...)
  .then(...)
  .encrypt(...)
  .render(...)
  .frame(...)
  .catch(...)
```
#### Build your own Promise
In this section we will create something different

For example you just want lazy
promises for better rendering performance by delaying heavy tasks.
You could just do:
```js
const later = (f)=> requestIdleCallback(f, {timeout: 500})
const Lazyness = promisync({
    then: later,
    catch: later,
    finally: later
  })
Lazyness.Promise
  .resolve(1)
  .then(...)
  .catch(...)
  .finally(...)

AWS.config.setPromisesDependency(Lazyness.Promise);
```
Or almost immediate, but framerate friendly Promise implementation:
```js
const afterFrame = (f)=> requestAnimationFrame(=> setTimeout(f))
const Framer = promisync({
      then: afterFrame,
      catch: afterFrame,
      finally: afterFrame,
      render: requestAnimationFrame
  })
Framer.Promise
  .resolve(
    // fetch and JSON parse are happening lazy on idle
    Lazyness.then(()=> fetch(...))
      .then((body)=> body.json())
  )
  // Framer's `then` will wait for current frame to render first
  .then(updateState)
  // `render` is part of Framer's promise chain
  .render((state, ts)=> updateDom(state))
  // if anything goes wrong
  .catch(...)
```
Look how much control over execution flow we gained
by just using promises

And now the most aggressive Promise implemetation but with
exception recovery
```js
const trySyncronously = (f)=> try{f()} catch(e){f.r(e)}
const PromiSync = promisync({
      then: syncronously,
      catch: syncronously,
      finally: syncronously
})
PromiSync.Promise.resolve(1)
  .then(...)
  .then(...)
  .then(...)
  .catch(...)
  .then(()=> console.log('chained')) // This logs first

console.log('syncronously') // This logs second
```



## Annotated Source

Importing [@playframe/proxy](https://github.com/playframe/proxy)

    proxy = require '@playframe/proxy'

Cheaply marking any value as rejected

    REJECTED = Symbol 'REJECTED'
    mark_rejected = (error)=>
      error = Object error # Object wrapper for primitives
      error[REJECTED] = true
      error

Defining a higher order function that takes
a prototype `sync` for our future promise chain.
`sync` needs only to implement the scheduling and
`try` `catch` if needed. Methods `catch` and `finally`
behave in Promise manner

    module.exports = (sync)=>

Lets use a tiny proxy implementation for creating
trapped objects with the same methods as `sync`

      methods = Object.keys sync
      make_proxy = proxy methods

`chained` is a higher order function that takes
a `schedule` function and handler `f` to wrap
`f` into chain resolver and pass it to `schedule`.
It returns a proxy object methods of which will
be executed after `f` is resolved

      chained = (schedule)=>(f)=>

Please note that
[closures](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Closures)
are _prefixed

        _done = false
        _result = null
        _chain = no_op

        resolve = (result)=>
          unless _done
            _done = true
            schedule _chain
            _result = result

        reject = (error)=> resolve mark_rejected error

        schedule wrap = (a...)=>
          unless _done
            result = f a...
            if result and result.then
              result.then resolve, reject
            else
              resolve result
            result

        wrap.r = reject

        make_proxy (method, f, recover)->
          if recover
            return @_h(method, f).catch recover

          delayed = sync[method]

          wrap = if method is 'finally'
            (x)=> f x; _result

          else if method is 'catch'
            (x)=>
              if _result[REJECTED]
                delete _result[REJECTED]
                f _result, x
              else
                _result
          else
            (x)=>
              if _result[REJECTED]
                _result
              else
                f _result, x

          # ✌️ combinator for nested chains
          chained((wrap)=>
            if _done
              delayed wrap
            else
              # chain of closures to call later
              # `do` does `_chain` closure
              # and returns second `=>`
              _chain = do (_chain)=>=>
                _chain()
                delayed wrap
          ) wrap

Now lets copy all methods from `sync` into returned
`chain` object by wrapping them in `chained`.
Also lets define `Promise` property of our
`chain` object.

      chain = methods.reduce ((chain, m)=>
        chain[m] = chained sync[m]
        chain
      ),
        Promise: Promise = (f)=>
          _awaiting = no_op
          # f(resolve, reject)
          f ((x)=> _awaiting x), (x)=> _awaiting mark_rejected x

          chained((resolver)=>
            _awaiting = (x)=> resolver x
          ) no_op

      Promise.resolve = (x)=> chain.then => x
      Promise.reject = (x)=> chain.catch => mark_rejected x

      Promise.race = (list)=> Promise (resolve, reject)=>
        {length} = list
        while length--
          list[length].then resolve, reject
        return

      Promise.all = (list)=> Promise (resolve, reject)=>
        {length} = list
        i = 0
        arr = Array length
        while i < length
          list[i].then (do (i)=>(x)=> # i closure
            arr[i] = x
            resolve arr unless --length
          ), reject
          i++
        return

      chain


    # Let's call it `id` function next time
    no_op = (x)=> x
