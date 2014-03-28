'use strict'

hold = angular.module('callveyor.dialer.hold', [])

hold.config([
  '$stateProvider'
  ($stateProvider) ->
    $stateProvider.state('dialer.hold', {
      views:
        callFlowButtons:
          templateUrl: "/scripts/dialer/hold/callFlowButtons.tpl.html"
          controller: 'HoldCtrl.buttons'
        callStatus:
          templateUrl: '/scripts/dialer/hold/callStatus.tpl.html'
          controller: 'HoldCtrl.status'
    })
])

hold.controller('HoldCtrl.buttons', [
  '$scope', '$state', '$timeout', 'caller', 'idDialerService', 'usSpinnerService',
  ($scope,   $state,   $timeout,   caller,   idDialerService,   usSpinnerService) ->
    console.log 'HoldCtrl.buttons', $scope

    hold = {}
    hold.campaign = caller.data.campaign
    hold.stopCalling = ->
      console.log 'stopCalling clicked'
      $state.go('dialer.stop')

    hold.dial = ->
      # update status > 'Dialing...'
      @callStatusText = 'Dialing...'
      usSpinnerService.spin('global-spinner')
      p = idDialerService.dial()
      s = (o) ->
        console.log 'dial success', o
        $state.go('dialer.active') # really will be triggered from pusher event
      e = (r) -> console.log 'error', r
      c = (r) -> console.log 'notify', r
      p.then(s,e,c)
      # POST /dial
      # then -> to 'active'
      # error -> update status > 'Error + explain, maybe try again'

    hold.skip = ->
      # update status > 'Skipping...'
      # POST /skip
      # then -> update contact
      # error -> update status > 'Error + explain, maybe try again'
    $scope.hold = hold
])

hold.controller('HoldCtrl.status', [
  '$scope', 'caller'
  ($scope,   caller) ->
    console.log 'HoldCtrl', caller

    hold = {}
    hold.callStatusText = switch caller.data.campaign.type
                            when 'Power', 'Predictive'
                              'Dialing...'
                            when 'Preview'
                              'Waiting to dial...'
                            else
                              'Oops! Please Report this problem.'

    $scope.hold = hold
])
