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
class ContentView < Katello::Model
  self.include_root_in_json = false

  include Ext::LabelFromName
  include Authorization::ContentView
  include Glue::ElasticSearch::ContentView if Katello.config.use_elasticsearch

  include Glue::Event

  def create_event
    Katello::Actions::ContentViewCreate
  end

  before_destroy :confirm_not_promoted # RAILS3458: this needs to come before associations

  belongs_to :content_view_definition, :class_name => "Katello::ContentViewDefinition", :inverse_of => :content_views
  alias_method :definition, :content_view_definition
  belongs_to :organization, :inverse_of => :content_views, :class_name => "Organization"

  has_many :content_view_environments, :class_name => "Katello::ContentViewEnvironment", :dependent => :destroy

  has_many :content_view_versions, :class_name => "Katello::ContentViewVersion", :dependent => :destroy
  alias_method :versions, :content_view_versions

  has_many :component_content_views, :class_name => "Katello::ComponentContentView", :dependent => :destroy
  has_many :distributors, :class_name => "Katello::Distributor", :dependent => :restrict
  has_many :composite_content_view_definitions,
    :through => :component_content_views, :source => "content_view_definition"

  has_many :changeset_content_views, :class_name => "Katello::ChangesetContentView", :dependent => :destroy
  has_many :changesets, :through => :changeset_content_views
  has_many :activation_keys, :class_name => "Katello::ActivationKey", :dependent => :restrict
  has_many :systems, :class_name => "Katello::System", :dependent => :restrict

  validates :label, :uniqueness => {:scope => :organization_id},
                    :presence => true
  validates :name, :presence => true, :uniqueness => {:scope => :organization_id}
  validates :organization_id, :presence => true

  validates_with Validators::KatelloNameFormatValidator, :attributes => :name
  validates_with Validators::KatelloLabelFormatValidator, :attributes => :label

  scope :default, where(:default => true)
  scope :non_default, where(:default => false)

  def self.in_environment(env)
    joins(:content_view_versions => :content_view_version_environments).
      where("#{Katello::ContentViewVersionEnvironment.table_name}.environment_id = ?", env.id)
  end

  def self.composite(composite = true)
    joins(:content_view_definition).where("#{Katello::ContentViewDefinitionBase.table_name}.composite = ?", composite)
  end

  def composite
    content_view_definition.try(:composite?)
  end

  def components_not_in_env(env)
    # If this view was published from a composite definition, return the
    # list of component content views, if any, that do not exist in the environment
    # provided.
    if composite
      content_view_definition.component_content_views.select("distinct #{Katello::ContentView.table_name}.*").
              joins(:content_view_versions => :content_view_version_environments).
              where(["#{Katello::ContentViewVersionEnvironment.table_name}.content_view_version_id "\
                     "NOT IN (SELECT content_view_version_id FROM "\
                     "#{Katello::ContentViewVersionEnvironment.table_name} WHERE environment_id = ?)",
                     env])
    end
  end

  def self.promoted(safe = false)
    # retrieve the view, if it has been promoted (i.e. exists in more than 1 environment)
    relation = select("distinct #{Katello::ContentView.table_name}.*").
               joins(:content_view_versions => :environments).
               where("#{Katello::KTEnvironment.table_name}.library" => false).
               where("#{Katello::ContentView.table_name}.default" => false)

    if safe
      # do not include group and having in returned relation
      self.where :id => relation.all.map(&:id)
    else
      relation
    end
  end

  def to_s
    name
  end

  def promoted?
    # if the view exists in more than 1 environment, it has been promoted
    self.environments.length > 1 ? true : false
  end

  #NOTE: this function will most likely become obsolete once we drop api v1
  def as_json(options = {})
    result = self.attributes
    result['organization'] = self.organization.try(:name)
    result['definition']   = self.content_view_definition.try(:name)
    result['environments'] = environments.map{|e| e.try(:name)}
    result['versions'] = versions.map(&:version)
    result['versions_details'] = versions.map do |v|
      {
        :version => v.version,
        :published => v.created_at.to_s,
        :environments => v.environments.map{|e| e.name}
      }
    end

    if options && options[:environment].present?
      result['repositories'] = repos(options[:environment]).map(&:name)
    end

    result
  end

  def environments
    KTEnvironment.joins(:content_view_versions).where("#{Katello::ContentViewVersion.table_name}.content_view_id" => self.id)
  end

  def in_environment?(env)
    environments.include?(env)
  end

  def version(env)
    self.versions.in_environment(env).order("#{Katello::ContentViewVersion.table_name}.id ASC").scoped(:readonly => false).last
  end

  def version_environment(env)
    # TODO: rewrite this into SQL or use content_view_environment when that
    # points to environment
    version(env).content_view_version_environments.select {|cvve| cvve.environment_id == env.id}
  end

  def repos(env)
    version = version(env)
    if version
      version.repositories.in_environment(env)
    else
      []
    end
  end

  def library_repos
    Repository.where(:id => library_repo_ids)
  end

  def library_repo_ids
    repos(self.organization.library).map { |r| r.library_instance_id }
  end

  def all_version_repos
    Repository.joins(:content_view_version).
      where("#{Katello::ContentViewVersion.table_name}.content_view_id" => self.id)
  end

  def repos_in_product(env, product)
    version = version(env)
    if version
      version.repositories.in_environment(env).in_product(product)
    else
      []
    end
  end

  def products(env)
    repos = repos(env)
    Product.joins(:repositories).where("#{Katello::Repository.table_name}.id" => repos.map(&:id)).uniq
  end

  #list all products associated to this view across all versions
  def all_version_products
    Product.joins(:repositories).where("#{Katello::Repository.table_name}.id" => self.all_version_repos).uniq
  end

  #get the library instances of all repos within this view
  def all_version_library_instances
    all_repos = all_version_repos.where(:library_instance_id => nil).pluck("#{Katello::Repository.table_name}.id")
    all_repos += all_version_repos.pluck(:library_instance_id)
    Repository.where(:id => all_repos)
  end

  def get_repo_clone(env, repo)
    lib_id = repo.library_instance_id || repo.id
    Repository.in_environment(env).where(:library_instance_id => lib_id).
        joins(:content_view_version).
        where("#{Katello::ContentViewVersion.table_name}.content_view_id" => self.id)
  end

  def promote_via_changeset(env, apply_options = {:async => true},
                            cs_name = "#{self.name}_#{env.name}_#{Time.now.to_i}")
    ActiveRecord::Base.transaction do
      cs = PromotionChangeset.create!(:name => cs_name,
                                      :environment => env,
                                      :state => Changeset::REVIEW
                                     )
      cs.add_content_view!(self)
      return cs.apply(apply_options)
    end
  end

  def promote(from_env, to_env)
    fail "Cannot promote from #{from_env.name}, view does not exist there." if !self.environments.include?(from_env)

    replacing_version = self.version(to_env)

    promote_version = self.version(from_env)
    promote_version = ContentViewVersion.find(promote_version.id)
    promote_version.environments << to_env unless promote_version.environments.include?(to_env)
    promote_version.save!

    repos_to_promote = get_repos_to_promote(from_env, to_env)
    if replacing_version
      PulpTaskStatus.wait_for_tasks prepare_repos_for_promotion(replacing_version.repos(to_env), repos_to_promote)
    end
    tasks = promote_repos(promote_version, to_env, repos_to_promote)

    if replacing_version
      replacing_version = ContentViewVersion.find(replacing_version.id) if replacing_version.readonly?
      if replacing_version.environments.length == 1
        replacing_version.destroy
      else
        replacing_version.environments.delete(to_env)
        replacing_version.save!
      end
    end

    Glue::Event.trigger(Katello::Actions::ContentViewPromote, self, from_env, to_env)

    tasks
  end

  def delete(from_env)
    if from_env.library? && in_non_library_environment?
      fail Errors::ChangesetContentException.new(_("Cannot delete view while it exists in environments"))
    end

    version = self.version(from_env)
    if version.nil?
      fail Errors::ChangesetContentException.new(_("Cannot delete from %s, view does not exist there.") % from_env.name)
    end
    version = ContentViewVersion.find(version.id)

    Glue::Event.trigger(Katello::Actions::ContentViewDemote, self, from_env)

    if foreman_env = Environment.find_by_katello_id(self.organization, from_env, self)
      foreman_env.destroy
    end

    version.delete(from_env)
    self.destroy if self.versions.empty?
  end

  def in_non_library_environment?
    environments.where(:library => false).length > 0
  end

  # Refresh the content view, creating a new version in the library.  The new version will be returned.
  # TODO: break up method
  # rubocop:disable MethodLength
  def refresh_view(options = { })
    if !content_view_definition.ready_to_publish?
      fail _("Cannot refresh view. Check definition for repository conflicts.")
    end
    content_view_definition.check_puppet_names!
    options = { :async => true, :notify => false }.merge options

    # retrieve the 'next' version id to use
    next_version_id = self.versions.maximum(:version) + 1

    # retrieve the version that is currently in the library and remove the library association.
    # at this point, we don't want to delete the version as we need to reference the repos it
    # contains during the refresh
    library_version = self.version(self.organization.library)

    # create a new version
    version = ContentViewVersion.new(:version => next_version_id, :content_view => self)
    version.environments << organization.library
    version.save!

    #move all the existing repos over to the new version
    library_version.repos(organization.library).scoped(:readonly => false).each do |repo|
      repo.content_view_version = version
      repo.save!
    end
    library_version.reload
    library_version.delete(self.organization.library)

    if options[:async]
      task  = version.async(:organization => self.organization,
                            :task_type => TaskStatus::TYPES[:content_view_refresh][:type]).
                      refresh_version(options[:notify])

      version.task_status = task
      version.save!
    else
      version.task_status = Katello::TaskStatus.create!(
                               :uuid => ::UUIDTools::UUID.random_create.to_s,
                               :user_id => ::User.current.id,
                               :organization => self.organization,
                               :state => Katello::TaskStatus::Status::WAITING,
                               :task_type => TaskStatus::TYPES[:content_view_refresh][:type])
      version.save!
      begin
        version.refresh_version(options[:notify])
        version.task_status.update_attributes!(:state => Katello::TaskStatus::Status::FINISHED)
      rescue => e
        version.task_status.update_attributes!(:state => Katello::TaskStatus::Status::ERROR)
        raise e
      end
    end
    version
  end

  def update_cp_content(env)
    # retrieve the environment and then update cp content
    view_env = self.content_view_environments.where(:environment_id => env.id).first
    view_env.update_cp_content if view_env
  end

  # Associate an environment with this content view.  This can occur whenever
  # a version of the view is promoted to an environment.  It is necessary for
  # candlepin to become aware that the view is available for consumers.
  def add_environment(env)
    if self.content_view_environments.where(:environment_id => env.id).empty?
      ContentViewEnvironment.create!(:name => env.name,
                                     :label => self.generate_cp_environment_label(env),
                                     :cp_id => self.generate_cp_environment_id(env),
                                     :environment_id => env.id,
                                     :content_view => self)
    end
  end

  # Unassociate an environment from this content view. This can occur whenever
  # a view is deleted from an environment. It is necessary to make candlepin
  # aware that the view is no longer available for consumers.
  def remove_environment(env)
    # Do not remove the content view environment, if there is still a view
    # version in the environment.
    if self.versions.in_environment(env).blank?
      view_env = self.content_view_environments.where(:environment_id => env.id)
      view_env.first.destroy unless view_env.blank?
    end
  end

  def cp_environment_label(env)
    ContentViewEnvironment.where(:content_view_id => self, :environment_id => env).first.label
  end

  def cp_environment_id(env)
    ContentViewEnvironment.where(:content_view_id => self, :environment_id => env).first.cp_id
  end

  protected

  def generate_cp_environment_label(env)
    # The label for a default view, will simply be the env label; otherwise, it
    # will be a combination of env and view label.  The reason being, the label
    # for a default view is internally generated (e.g. 'Default_View_for_dev')
    # and we do not need to expose it to the user.
    self.default ? env.label : [env.label, self.label].join('/')
  end

  def generate_cp_environment_id(env)
    # The id for a default view, will simply be the env id; otherwise, it
    # will be a combination of env id and view id.  The reason being,
    # for a default view, the same candlepin environment will be referenced
    # by the kt_environment and content_view_environment.
    self.default ? env.id.to_s : [env.id, self.id].join('-')
  end

  def get_repos_to_promote(from_env, to_env)
    # Retrieve the repos that will end up in the to_env as a result of promoting this view.
    # The structure will be a hash, where key=repo.library_instance_id and value=repo
    if self.content_view_definition.try(:composite?)
      # For a composite view, the repos are based upon the component_content_views
      # currently in the to_env
      promoting_repos = Repository.in_environment(to_env).
          in_content_views(self.content_view_definition.component_content_views).
          inject({}) do |result, repo|
        result.update repo.library_instance_id => repo
      end
    else
      # For a non-composite view, the repos are based upon the repos in
      # the from_env
      promoting_repos = self.repos(from_env).inject({}) do |result, repo|
        result.update repo.library_instance_id => repo
      end
    end
    promoting_repos
  end

  def prepare_repos_for_promotion(repos_to_replace, repos_to_promote)
    tasks = repos_to_replace.inject([]) do |result, repo|
      if repos_to_promote.key?(repo.library_instance_id)
        # a version of this repo is being promoted, so clear it and later
        # we'll regenerate the content... this is more efficient than
        # destroying the repo and recreating it...
        result += repo.clear_contents
      else
        # a version of this repo is not being promoted, so destroy it
        repo.destroy
        result
      end
    end
    tasks
  end

  def promote_repos(promote_version, to_env, promoting_repos)
    # promote the repos to the target env
    tasks = []
    promoting_repos.each_pair do |library_instance_id, repo|
      clone = self.get_repo_clone(to_env, repo).first
      if clone.nil?
        # this repo doesn't currently exist in the next environment, so create it
        clone = repo.create_clone(to_env, self)
        tasks << repo.clone_contents(clone)
      else
        # this repo already exists in the next environment, so update it
        clone = Repository.find(clone) # reload readonly obj
        clone.content_view_version = promote_version
        clone.save!
        tasks << repo.clone_contents(clone)
      end
    end
    tasks
  end

  def confirm_not_promoted
    if promoted?
      errors.add(:base, _("cannot be deleted if it has been promoted."))
      return false
    end
    return true
  end

end
end
