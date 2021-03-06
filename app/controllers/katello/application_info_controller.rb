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

module Katello
class ApplicationInfoController < Katello::ApplicationController
  skip_before_filter :authorize

  def section_id
    # use the dashboard layout
    "dashboard"
  end

  def title
    _('Application Information')
  end

  def menu_definition
    {:about => :admin_menu}.with_indifferent_access
  end

  def about
    @ping = Ping.ping
    @packages = Ping.packages
    @system_info = {  _("Application") => Katello.config.app_name,
                      _("Version")     => Katello.config.katello_version
                   }
    if ::User.allowed_to?(:read, :organizations)
      @system_info.merge!(_("Environment") => Rails.env,
                          _("Directory")   => Rails.root,
                          _("Authentication") => Katello.config.warden,
                          "Ruby" => RUBY_VERSION
                         )
    end
  end
end
end
