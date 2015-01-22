'strict'

household = angular.module('callveyor.household', [
  'idCacheFactories'
])

household.controller('HouseholdCtrl', [
  '$rootScope', '$scope', '$state', '$http', '$sce', 'HouseholdCache',
  ($rootScope,   $scope,   $state,   $http,   $sce,   HouseholdCache) ->
    handleStateChange = (event, toState, toParams, fromState, fromParams) ->
      switch toState.name
        when 'dialer.stop', 'dialer.ready'
          $scope.household = {}

    updateFromCache = ->
      data    = angular.copy(HouseholdCache.get('data'))
      console.log 'updating household from cache', data
      members = []
      angular.forEach(data.members, (member) ->      
        trustedFields = {}
        angular.forEach(member.fields, (value, key) ->
          trustedFields[key] = $sce.trustAsHtml(value)
        )

        trustedCustomFields = []
        angular.forEach(member.custom_fields, (value, key) ->
          trusted = [$sce.trustAsHtml(key), $sce.trustAsHtml(value)]
          trustedCustomFields.push(trusted)
        )

        member.fields        = trustedFields
        member.custom_fields = trustedCustomFields

        members.push(member)
      )
      console.log 'setting household members', members
      $scope.household = {
        phone: data.phone,
        members: members
      }

    $rootScope.$on('household:changed', updateFromCache)
    $rootScope.$on('$stateChangeSuccess', handleStateChange)

    $scope.household = household
])

household.directive('idHousehold', ->
  {
    restrict: 'A'
    templateUrl: '/callveyor/dialer/household/household.tpl.html'
  }
)