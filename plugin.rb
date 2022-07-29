# name: discourse-onebox-weibo
# about: 为 Discourse Onebox 增加微博支持
# version: 0.1.9
# authors: pangbo13
# url: https://github.com/pangbo13/discourse-onebox-weibo

# redis-cli flushall

require_relative "../../lib/onebox"

enabled_site_setting :weibo_onebox_priority

register_asset "stylesheets/common/weibo-onebox.scss"

after_initialize do
    Onebox.options.load_paths.push(File.join(File.dirname(__FILE__), "templates"))
end

after_initialize do
    module ::Onebox
        module Engine
            class WeiboOnebox
                include Engine
                include LayoutSupport
                matches_regexp(/^(?:(?:https?:\/\/)?(?:(passport\.weibo\.com\/visitor\/visitor\?.+)|(m\.weibo\.cn\/(?:detail|status)\/.+)|(share\.api\.weibo\.cn\/share\/.+)))$/)
                always_https

                GOOGLE_UA = "Googlebot/2.1 (+http://www.google.com/bot.html)"

                def self.priority
                    SiteSetting.weibo_onebox_priority rescue 100
                end

                def mobile?
                    @mobile ||= (uri.host == "m.weibo.cn")
                end

                def share_api?
                    @share_api ||= (uri.host == "share.api.weibo.cn")
                end

                def desktop?
                    @desktop ||= (uri.host == "passport.weibo.com")
                end

                def raw_url
                    if @raw_url
                        return @raw_url
                    end
                    if mobile? || share_api?
                        @raw_url = uri.to_s
                    else    # for passport.weibo.com
                        # read url form params
                        @raw_url = CGI.parse(uri.query)['url'].first
                    end
                end

                def response
                    @response ||= get_response!
                end

                def get_response!
                    ::Onebox::Helpers.fetch_response(raw_url,
                        headers:{"User-Agent" => GOOGLE_UA}) rescue nil
                end

                def weibo_data
                    if @weibo_data
                        return @weibo_data
                    end
                    weibo_meta_data = {}
                    if mobile?      #m.weibo.cn
                        page_info = ::JSON.parse(response.scan(/render_data = (.*?)\[0\]/m)[0][0])[0]
                        content = Nokogiri::HTML(page_info["status"]["text"])&.text
                        weibo_meta_data[:'title'] = page_info["status"]["status_title"]
                        weibo_meta_data[:'description'] = content
                        weibo_meta_data[:'img'] = page_info["status"]["thumbnail_pic"]
                    elsif share_api?    #share.api.weibo.cn
                        html = Nokogiri::HTML(response)
                        weibo_meta_data[:'description'] = html&.at_css(".weibo-text")&.text&.strip
                        weibo_meta_data[:'img'] = html&.at_css(".card-main img")["src"] rescue nil
                        user_name = html&.at_css(".weibo-top span")&.text&.strip
                        if !user_name.nil?
                            I18n.with_locale(SiteSetting.default_locale.to_sym) do
                                weibo_meta_data[:'title'] =  I18n.t("weibo_onebox.title_by_user_name", user_name: user_name)
                            end
                        end
                    else    # passport.weibo.com
                        html = Nokogiri::HTML(response)
                        html.css('meta').each do |m|
                            if m.attribute('name') && m.attribute('content') 
                                m_content = m.attribute('content').to_s
                                m_name = m.attribute('name').to_s
                                weibo_meta_data[m_name.to_sym] = m_content
                            end
                        end
                        weibo_meta_data[:'title'] = html.at_css('title').text
                    end
                    @weibo_data = weibo_meta_data
                end

                def data
                    @data ||= I18n.with_locale(SiteSetting.default_locale.to_sym) do
                        {
                            link: raw_url.to_s,
                            keywords: weibo_data[:keywords] || raw_url.to_s,
                            description: weibo_data[:description]&.truncate(100),
                            title: weibo_data[:title] || I18n.t("weibo_onebox.name_of_weibo"),
                            image: weibo_data[:img]
                        }
                    end
                rescue StandardError => err
                    # puts err
                    I18n.with_locale(SiteSetting.default_locale.to_sym) do
                        {
                            link: raw_url.to_s,
                            title: I18n.t("weibo_onebox.name_of_weibo")
                        }
                    end
                end
            end
        end
    end
end