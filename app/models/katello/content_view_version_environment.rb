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
class ContentViewVersionEnvironment < Katello::Model
  self.include_root_in_json = false

  belongs_to :environment, :class_name => 'Katello::KTEnvironment', :inverse_of => :content_view_version_environments
  belongs_to :content_view_version, :inverse_of => :content_view_version_environments

  before_create :verify_not_exists

  def verify_not_exists
    if self.content_view_version.environments.include?(self.environment)
      fail _("Content View %{view} is already in environment %{env}") % {:view => self.content_view_version.content_view.name, :env => self.environment.name}
    end
  end

end
end
