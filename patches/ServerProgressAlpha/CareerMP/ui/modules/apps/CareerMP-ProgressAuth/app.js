var app = angular.module('beamng.apps');

app.directive('careermpprogressauth', [function () {
  return {
    templateUrl: '/ui/modules/apps/CareerMP-ProgressAuth/app.html',
    replace: true,
    restrict: 'EA',
    scope: true
  };
}]);

app.controller('CareerMPProgressAuthController', ['$scope', '$interval', function ($scope, $interval) {
  $scope.state = {
    enabled: false,
    authenticated: false,
    inFlight: false,
    message: 'Waiting for server progress configuration...'
  };
  $scope.form = {
    username: localStorage.getItem('careerMPProgressUsername') || '',
    password: ''
  };

  function escapeLuaString(value) {
    return String(value || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  }

  function applyState(data) {
    var parsed = data;
    if (typeof parsed === 'string') {
      try {
        parsed = JSON.parse(parsed);
      } catch (error) {
        return;
      }
    }
    if (!parsed) return;
    $scope.state = parsed;
    $scope.state.registrationDisabled = parsed.registrationDisabled === true;
    if (parsed.username && !$scope.form.username) {
      $scope.form.username = parsed.username;
    }
    $scope.$evalAsync();
  }

  function refreshState() {
    bngApi.engineLua('careerMPProgressClient.getUiState()', applyState);
  }

  $scope.init = function () {
    refreshState();
  };

  $scope.engageFocus = function () {
    bngApi.engineLua('setCEFFocus(true)');
  };

  $scope.releaseFocus = function () {
    bngApi.engineLua('setCEFFocus(false)');
  };

  $scope.login = function () {
    localStorage.setItem('careerMPProgressUsername', $scope.form.username || '');
    bngApi.engineLua('careerMPProgressClient.login("' + escapeLuaString($scope.form.username) + '", "' + escapeLuaString($scope.form.password) + '")');
    setTimeout(refreshState, 250);
  };

  $scope.register = function () {
    localStorage.setItem('careerMPProgressUsername', $scope.form.username || '');
    bngApi.engineLua('careerMPProgressClient.register("' + escapeLuaString($scope.form.username) + '", "' + escapeLuaString($scope.form.password) + '")');
    setTimeout(refreshState, 250);
  };

  var refreshTimer = $interval(refreshState, 750);
  $scope.$on('$destroy', function () {
    bngApi.engineLua('setCEFFocus(false)');
    $interval.cancel(refreshTimer);
  });
}]);
