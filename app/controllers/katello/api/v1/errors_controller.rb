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
class Api::V1::ErrorsController < Api::V1::ApiController

  skip_before_filter :require_user
  skip_before_filter :authorize

  def render_404
    # rubocop:disable SymbolName
    render :json => { :displayMessage => _("Resource not found on the server"), :errors => [_("Not found")] }, :status => 404
  end
end
end
