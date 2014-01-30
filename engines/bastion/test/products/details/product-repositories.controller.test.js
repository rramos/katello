/**
 * Copyright 2014 Red Hat, Inc.
 *
 * This software is licensed to you under the GNU General Public
 * License as published by the Free Software Foundation; either version
 * 2 of the License (GPLv2) or (at your option) any later version.
 * There is NO WARRANTY for this software, express or implied,
 * including the implied warranties of MERCHANTABILITY,
 * NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
 * have received a copy of GPLv2 along with this software; if not, see
 * http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
 **/

describe('Controller: ProductRepositoriesController', function() {
    var $scope, $q, expectedTable, expectedIds, Repository, RepositoryBulkAction, Nutupane;

    beforeEach(module('Bastion.products', 'Bastion.test-mocks'))

    beforeEach(inject(function($injector) {
        var $controller = $injector.get('$controller'),
            $q = $injector.get('$q'),
            rows = [{id: 1, name: 'blah'}, {id: 2, name: 'blah2'}];

        expectedTable = {
            rows: rows,
            showColumns: function() {},
            getSelected: function() {
                return [rows[1]];
            },
            selectAll: function() {},
            allSelected: false
        };

        expectedIds = _.pluck(rows, 'id');

        Nutupane = function() {
            this.table = expectedTable;
            this.removeRow = function() {};
            this.get = function() {};
            this.query = function() {};
            this.refresh = function() {};
            this.getAllSelectedResults = function() {
                return {
                    included: { ids: expectedIds }
                };
            };
        };

        $scope = $injector.get('$rootScope').$new();
        $scope.$stateParams = {productId: 1};

        Repository = $injector.get('MockResource').$new();

        RepositoryBulkAction = $injector.get('MockResource').$new();
        RepositoryBulkAction.syncRepositories = function(params, success, error) {
            return {'$promise': $q.defer().promise};
        };
        RepositoryBulkAction.removeRepositories = function(params, success, error) {
            return {'$promise': $q.defer().promise};
        };

        $controller('ProductRepositoriesController', {
            $scope: $scope,
            Repository: Repository,
            RepositoryBulkAction: RepositoryBulkAction,
            CurrentOrganization: 'ACME',
            Nutupane: Nutupane
        });
    }));

    it("sets up the repositories nutupane table", function() {
        expect($scope.repositoriesTable).toBe(expectedTable);
    });

    it('should provide a way to remove a repository', function() {
        var repository = new Repository();
        repository.id = 1;
        spyOn($scope, 'transitionTo');

        $scope.removeRepository(repository);

        expect($scope.transitionTo).toHaveBeenCalled();
    });

    it("provides a way to remove all of the selected repositories in the table", function() {
        spyOn(RepositoryBulkAction, 'removeRepositories').andCallThrough();

        $scope.removeSelectedRepositories();
        expect(RepositoryBulkAction.removeRepositories).toHaveBeenCalledWith({ids: expectedIds},
            jasmine.any(Function), jasmine.any(Function));
    });
    
    it("provides a way to sync all of the selected repositories in the table", function() {
        spyOn(RepositoryBulkAction, 'syncRepositories').andCallThrough();

        $scope.syncSelectedRepositories();
        expect(RepositoryBulkAction.syncRepositories).toHaveBeenCalledWith({ids: expectedIds},
            jasmine.any(Function), jasmine.any(Function));
    });
});
