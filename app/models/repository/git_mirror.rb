
require 'open3'

class Repository::GitMirror < Repository::Git

  before_validation :validate_url, on: :create
  before_validation :set_defaults, on: :create
  after_validation :init_repo, on: :create
  after_commit :fetch, on: :create

  before_destroy :remove_repo

  private def remove_repo
    return if root_url.to_s.empty? || root_url == '/'
    return unless Dir.exist? root_url

    FileUtils.rm_rf root_url
  end

  private def validate_url
    return if url.to_s.empty?

    begin
      parsed_url = ::GitMirror::URL.parse(url)
    rescue Exception => msg
      errors.add :url, msg.to_s
      return
    end

    unless parsed_url.remote?
      errors.add :url, 'should be remote url'
      return
    end

    err = ::GitMirror::Git.check_remote_url(parsed_url)
    errors.add :url, err if err
  end

  private def set_defaults
    return unless self.errors.empty? && !url.to_s.empty?

    parsed_url = ::GitMirror::URL.parse(url)
    if identifier.empty?
      identifier = File.basename(parsed_url.path, ".*")
      self.identifier = identifier if /^[a-z][a-z0-9_-]*$/.match(identifier)
    end

    self.root_url = ::GitMirror::Settings.path + '/' +
      Time.now.strftime("%Y%m%d%H%M%S%L") +
      "_" +
      (parsed_url.host + parsed_url.path).gsub(/[\\\/]+/, '_').gsub(/[^A-Za-z._-]/, '')[0..64]
  end

  private def init_repo
    return unless self.errors.empty?

    err = ::GitMirror::Git.init(root_url, url)
    errors.add :url, err if err
  end

  def fetch_changesets
    fetch
    super()
  end

  def fetch
    return if @fetched
    @fetched = true

    puts "Fetching repo #{root_url}"

    err = ::GitMirror::Git.fetch(root_url, url)
    Rails.logger.warn 'Err with fetching: ' + err if err

    fetch_changesets
  end

  class << self
    def scm_name
      'Git Mirror'
    end

    def human_attribute_name(attribute_key_name, *args)
      attr_name = attribute_key_name.to_s

      Repository.human_attribute_name(attr_name, *args)
    end
  end

end