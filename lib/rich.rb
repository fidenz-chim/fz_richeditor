if Object.const_defined?('RailsAdmin')
  require 'rich/rails_admin/config/fields/types/rich_picker'
  require 'rich/rails_admin/config/fields/types/rich_editor'
end

require 'rich/engine'

module Rich
  # configure image styles
  def self.image_styles
    @@image_styles.merge(rich_thumb: '100x100#')
  end

  def self.image_styles=(image_styles)
    @@image_styles = image_styles
  end
  @@image_styles = {
    thumb: '100x100#'
  }

  mattr_accessor :convert_options
  @@convert_options = {}

  mattr_accessor :allowed_styles
  @@allowed_styles = :all

  mattr_accessor :default_style
  @@default_style = :thumb

  mattr_accessor :authentication_method
  @@authentication_method = :none

  mattr_accessor :insert_many
  @@insert_many = false

  mattr_accessor :allow_document_uploads
  @@allow_document_uploads = false

  mattr_accessor :allow_embeds
  @@allow_embeds = false

  mattr_accessor :allowed_image_types
  @@allowed_image_types = ['image/jpeg', 'image/png', 'image/gif', 'image/jpg']

  mattr_accessor :allowed_video_types
  @@allowed_video_types = ['video/avi', 'video/mp4', 'video/x-ms-wmv',
                           'video/mpeg', 'video/3gpp',
                           'application/octet-stream', 'video/webm']

  mattr_accessor :allowed_audio_types
  @@allowed_audio_types = ['audio/mpeg3', 'audio/x-mpeg-3', 'audio/mpeg', 'audio/mp3']

  mattr_accessor :allowed_document_types
  @@allowed_document_types = :all

  mattr_accessor :file_path
  @@file_path

  mattr_accessor :backend
  @@backend = :paperclip

  # configuration for picker
  mattr_accessor :placeholder_image
  @@placeholder_image = 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==' # a transparent pixel

  mattr_accessor :preview_size
  @@preview_size = '100px'

  mattr_accessor :hidden_input
  @@hidden_input = false
  # end configuration for picker

  # Configuration defaults (these map directly to ckeditor settings)
  mattr_accessor :editor
  @@editor = {
    height: 400,
    stylesSet: [],
    extraPlugins: 'stylesheetparser,richfile,mediaembed,showblocks',
    removePlugins: 'scayt,image,forms',
    contentsCss: :default,
    removeDialogTabs: 'link:advanced;link:target',
    startupOutlineBlocks: true,
    forcePasteAsPlainText: true,
    format_tags: 'h3;p;pre',
    toolbar: [%w(Styles Format Font FontSize), %w(Bold Italic Underline Strike Subscript Superscript),
              %w(JustifyLeft JustifyCenter JustifyRight JustifyBlock), %w(TextColor BGColor),
              %w(RemoveFormat), %w(NumberedList BulletedList Blockquote), %w(Link Unlink),
              %w(richImage richFile MediaEmbed), %w(Source ShowBlocks)],
    language: I18n.default_locale,
    richBrowserUrl: '/rich/files/',
    uiColor: '#f4f4f4'
  }
  # End configuration defaults

  mattr_accessor :paginates_per
  @@paginates_per = 34

  def self.options(overrides = {}, scope_type = nil, scope_id = nil)
    # merge in editor settings configured elsewhere

    if allowed_styles == :all
      # replace :all with a list of the actual styles that are present
      all_styles = Rich.image_styles.keys
      all_styles.push(:original)
      self.allowed_styles = all_styles
    end

    base = {
      allowed_styles: allowed_styles,
      default_style: default_style,
      insert_many: insert_many,
      allow_document_uploads: allow_document_uploads,
      allow_embeds: allow_embeds,
      placeholder_image: placeholder_image,
      preview_size: preview_size,
      hidden_input: hidden_input,
      paginates_per: paginates_per
    }
    editor_options = editor.merge(base)

    # merge in local overrides
    editor_options.merge!(overrides) if overrides

    # if the contentcss is set to :default, use the asset pipeline
    editor_options[:contentsCss] = ActionController::Base.helpers.stylesheet_path('rich/editor.css') if editor_options[:contentsCss] == :default

    # update the language to the currently selected locale
    editor_options[:language] = I18n.locale

    # remove the filebrowser if allow_document_uploads is false (the default)
    unless editor_options[:allow_document_uploads]
      editor_options[:toolbar].map { |a| a.delete 'richFile'; a }
    end

    unless editor_options[:allow_embeds]
      editor_options[:toolbar].map { |a| a.delete 'MediaEmbed'; a }
    end

    # object scoping
    # todo: support scoped=string to scope to collections, set id to 0
    unless editor_options[:scoped].nil?

      # true signifies object level scoping
      if editor_options[:scoped] == true

        if !scope_type.nil? && !scope_id.nil?
          editor_options[:scope_type] = scope_type
          editor_options[:scope_id] = scope_id
        else
          # cannot scope new objects
          editor_options[:scoped] = false
        end

      else

        # not true (but also not nil) signifies scoping to a collection
        if !scope_type.nil?
          editor_options[:scope_type] = editor_options[:scoped]
          editor_options[:scope_id] = 0
          editor_options[:scoped] = true
        else
          editor_options[:scoped] = false
        end

      end
    end

    editor_options
  end

  def self.validate_mime_type(mime, simplified_type)
    # does the mimetype match the given simplified type?
    # puts "matching:" + mime + " TO " + simplified_type
    case simplified_type
    when 'image'
      return true if allowed_image_types.include?(mime)
    when 'audio'
      return true if mime.include? 'audio'
    when 'video'
      return true if mime.include?('video') || mime.include?('webm') || mime.include?('mp4')
    when 'file'
      if allowed_document_types == :all || allowed_document_types.include?(mime)
        return true
      else
        return false
      end
    else
      return false
    end
  end

  def self.setup
    yield self
  end

  def self.insert
    # manually inject into Formtastic 1. V2 is extended autmatically.
    if Object.const_defined?('Formtastic')
      if Gem.loaded_specs['formtastic'].version.version[0, 1] == '1'
        require 'rich/integrations/legacy_formtastic'
        ::Formtastic::SemanticFormBuilder.send :include, Rich::Integrations::FormtasticBuilder
      end
    end

    if backend == :paperclip
      require 'rich/backends/paperclip'
    elsif backend == :carrierwave
      require 'rich/backends/carrierwave'
    end
  end
end
