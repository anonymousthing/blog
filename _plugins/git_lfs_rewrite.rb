module GitLfsRewrite
  def git_lfs_rewrite(relative_url)
    env = ENV['JEKYLL_ENV'] || 'development'
    is_dev = env == 'development'
    asset_host = is_dev ? '' : 'https://media.githubusercontent.com/media/bitnimble/bitnimble.github.io/gh-pages'
    "#{asset_host}#{relative_url}"
  end
end

Liquid::Template.register_filter(GitLfsRewrite)
