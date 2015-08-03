module AppearancesHelper
  def brand_item
    nil
  end

  def brand_title
    'GitLab Community Edition'
  end

  def brand_image
    nil
  end

  def brand_text
    nil
  end
  def brand_main_logo
  image_tag 'screenpages_large.png'
  end 
  def brand_header_logo
  #  image_tag 'logo.svg'
  image_tag 'screenpages.png'
  end
  def brand_header_icon
  image_tag 'screenpages_icon.png'
  end 
end
