#
# Copyright 2013 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require "katello_test_helper"

module Katello
describe EnvironmentsController do
  before do
    setup_engine_routes
  end

  describe "routing" do

    it "recognizes and generates #index" do
      { :method => :get, :path => "/organizations/1/environments" }.must_route_to({:controller => "katello/environments", :action => "index", :organization_id => "1"})
    end

    it "recognizes and generates #new" do
      { :method => :get, :path => "/organizations/1/environments/new" }.must_route_to({:controller => "katello/environments", :action => "new", :organization_id => "1"})
    end

    it "recognizes and generates #show" do
      { :method => :get, :path => "/organizations/1/environments/1" }.must_route_to({:controller => "katello/environments", :action => "show", :id => "1", :organization_id => "1"})
    end

    it "recognizes and generates #edit" do
      { :method => :get, :path => "/organizations/1/environments/1/edit" }.must_route_to({:controller => "katello/environments", :action => "edit", :id => "1", :organization_id => "1"})
    end

    it "recognizes and generates #create" do
      { :method => :post, :path => "/organizations/1/environments" }.must_route_to({:controller => "katello/environments", :action => "create", :organization_id => "1"})
    end

    it "recognizes and generates #update" do
      { :method => :put, :path => "/organizations/1/environments/1" }.must_route_to({:controller => "katello/environments", :action => "update", :id => "1", :organization_id => "1"})
    end

    it "recognizes and generates #destroy" do
      { :method => :delete, :path => "/organizations/1/environments/1" }.must_route_to({:controller => "katello/environments", :action => "destroy", :id => "1", :organization_id => "1"})
    end

  end
end
end
