'use strict'

callveyor = angular.module('callveyor')

callveyor.factory('idFlashService', [
  '$timeout',
  ($timeout) ->
    console.log 'flash factory'

    flash = {
      _validKeys: ['success', 'notice', 'warning', 'error']
      clear: ->
        for key in flash._validKeys
          if flash[key]?
            flash[key] = undefined
            $timeout(-> flash.scope.$apply())
      now: (key, msg, autoRemoveSeconds) ->
        autoRemoveSeconds ||= 0
        @clear()
        for k in @_validKeys
          if key == k
            console.log 'match', key, k
            @[k] = msg
            $timeout(-> flash.scope.$apply())
        if autoRemoveSeconds > 0
          $timeout(@clear, autoRemoveSeconds)

        @
    }

    flash
])
