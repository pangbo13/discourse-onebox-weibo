# name: discourse-onebox-weibo
# about: 为 Discourse Onebox 增加微博支持
# version: 0.1.0
# authors: pangbo13
# url: https://github.com/pangbo13/discourse-onebox-weibo

Onebox = Onebox

after_initialize do
    Onebox.options.load_paths.push(File.join(File.dirname(__FILE__), "templates"))
end

module Onebox
    module Engine
        class WeiboOnebox
            include Engine
            include LayoutSupport

            matches_regexp(/^(https?:\/\/)?passport\.weibo\.com\/visitor\/visitor\?.+$/)
            always_https

            GOOGLE_UA = "Googlebot/2.1 (+http://www.google.com/bot.html)"

            def raw_url
                @raw_url ||= CGI.parse(uri.query)['url'].first
            end

            def weibo_data
                if @weibo_data
                    return @weibo_data
                end
                response = Onebox::Helpers.fetch_response(raw_url,
                    headers:{"User-Agent" => GOOGLE_UA}) rescue nil
                html = Nokogiri::HTML(response)
                weibo_meta_data = {}
                
                html.css('meta').each do |m|
                    puts m
                    if m.attribute('name') && m.attribute('content') 
                        m_content = m.attribute('content').to_s
                        m_name = m.attribute('name').to_s
                        weibo_meta_data[m_name.to_sym] = m_content
                    end
                end
                @weibo_data = weibo_meta_data
            end

            def data
                @data ||= {
                    link: raw_url.to_s,
                    keywords: weibo_data[:keywords] || raw_url.to_s,
                    description: weibo_data[:description],
                }
            rescue
                {}
            end
        end
    end
end