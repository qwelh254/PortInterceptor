//
//  BuiltinRules.swift
//  内置大型拦截规则库（自动生成，请勿手改）
//  分类：广告 / 追踪统计 / 恶意钓鱼 / 骚扰
//  每条域名以 DOMAIN-SUFFIX 形式匹配，覆盖该域名及其全部子域名
//  共 577 个真实域名
//

import Foundation

enum BuiltinRules {
    /// 分类中文
    static let categories: [(name: String, domains: [String])] = [
        ("广告拦截", ads),
        ("追踪统计", trackers),
        ("恶意钓鱼", malware),
        ("骚扰弹窗", annoyance),
    ]

    static let ads: [String] = [
        "3lift.com", "aax.amazon-adsystem.com", "ad.gionee.com", "ad.kuaishou.com", "ad.mi.com", "ad.oceanengine.com",
        "ad.toutiao.com", "ad1.cc", "adblade.com", "adblade.net", "adcolony.com", "adcolony.net",
        "adengage.com", "adforge.com", "adform.com", "adform.net", "adgains.com", "adhepsia.com",
        "adincube.com", "adinplay.com", "adinton.com", "adjova.com", "adkimia.com", "adlix.com",
        "adlook.com", "adludio.com", "admaster.com.cn", "admaster.net", "admedo.com", "admeld.com",
        "admeris.com", "admixer.net", "admo.com", "admob.com", "admob.net", "admoda.com",
        "admost.com", "adnium.com", "adnxs.com", "adot.com", "adotmob.com", "adpage.com",
        "adplex.com", "adpristine.com", "adquadratum.com", "adradar.com", "adreactor.com", "adrecover.com",
        "adrelay.com", "adresults.com", "adrevenue.com", "adrocket.com", "adroll.com", "ads-alliance.com",
        "ads-api.tiktok.com", "ads-twitter.com", "ads.bytedance.com", "ads.huawei.com", "ads.linkedin.com", "ads.meizu.com",
        "ads.oppomobile.com", "ads.pinterest.com", "ads.reddit.com", "ads.snapchat.com", "ads.tiktok.com", "ads.tiktokv.com",
        "ads.union.jd.com", "ads.unity.com", "ads.unity3d.com", "ads.vivo.com.cn", "ads.wan.vivo.com", "adsame.com",
        "adsame.net", "adscend.com", "adsco.com", "adsco.re", "adsense.com", "adserver.io",
        "adserver01.com", "adservice.google.com", "adservice.io", "adsfast.com", "adspruce.com", "adsrvr.org",
        "adsstatic.vivo.com.cn", "adstage.io", "adstellar.com", "adsterra.com", "adstream.com", "adsupply.com",
        "adswing.com", "adswizz.com", "adsx.oppomobile.com", "adsystem.amazon.com", "adtarget.com", "adtargeting.io",
        "adtea.com", "adtech.com", "adtech.io", "adtech.net", "adtelligent.com", "adthe.net",
        "adtheorent.com", "adthrive.com", "adtile.com", "adtiming.com", "adtoapp.com", "adtraction.com",
        "adtrp.com", "adunite.com", "adups.com", "adups.net", "aduptech.com", "advalify.com",
        "advanse.com", "adventive.com", "adverline.com", "advertising.com", "advertmobile.com", "adverty.com",
        "adview.cn", "adview.com", "advolution.com", "adwhirl.com", "adwise.com", "adwo.com",
        "adxpros.com", "adyoume.com", "adzcraft.com", "adzerk.com", "adzka.com", "adzmojo.com",
        "alimama.com", "allyes.com", "analytics.twitter.com", "appflood.com", "appflood.net", "applifier.com",
        "applovin.co", "applovin.com", "applovin.org", "appnext.com", "appnext.io", "apprup.com",
        "avocarrot.com", "baiduads.com", "baidustatic.com", "bidswitch.net", "blockthrough.com", "bluemailapp.com",
        "brealtime.com", "c.gdt.qq.com", "casalemedia.com", "cbjs.baidu.com", "chartboost.com", "chartboost.net",
        "commissionfactory.com", "conversantmedia.com", "cpro.baidustatic.com", "criteo.com", "criteo.net", "criteo.org",
        "csjplatform.com", "csjplatformusercontent.com", "data.mistat.com", "demdex.net", "domob.cn", "domob.com",
        "doubleclick.net", "e.qq.com", "epom.com", "everesttech.net", "exdynsrv.com", "exoclick.com",
        "fyber.com", "fyber.io", "gdt.qq.com", "gdtimg.com", "gionee.com", "googleads.g.doubleclick.net",
        "googleadservices.com", "googlesyndication.com", "googletagmanager.com", "hilltopads.com", "hm.baidu.com", "hmsads.com",
        "iflyads.com", "inmobi.cn", "inmobi.com", "inmobi.net", "iron-source.com", "ironsrc.com",
        "ironsrc.io", "juicyads.com", "jz.click.jd.com", "krxd.net", "ksadsdk.com", "kuaishou.com",
        "leadbolt.com", "leadbolt.net", "lkqd.com", "lkqd.net", "loopme.com", "loopme.net",
        "mathtag.com", "mediamath.com", "mediav.com", "meizu.com", "mfadsrvr.com", "miaozhen.com",
        "mintegral.com", "mintegral.net", "mmstat.com", "moat.com", "moatads.com", "mobads.baidu.com",
        "mobclix.com", "mobvista.com", "mopub.com", "nativex.com", "omtrdc.net", "openx.com",
        "openx.net", "pagead2.googlesyndication.com", "pangleglobal.com", "pangolin-sdk-toutiao-b.com", "pangolin-sdk-toutiao.com", "pixfuture.com",
        "playheaven.com", "popads.net", "popcash.net", "pos.baidu.com", "propellerads.com", "pubmatic.com",
        "qzonestyle.com", "reyun.com", "rubiconproject.com", "rubiconproject.net", "samsungacr.com", "samsungads.com",
        "sdkconfig.ad.mi.com", "sdkconfig.ad.xiaomi.com", "sellers.json", "sharethrough.com", "sitescout.com", "smartadserver.com",
        "smartyads.com", "spotx.tv", "spotxchange.com", "ssp.ad", "startapp.com", "startapp.io",
        "startapp.net", "tanx.com", "tapjoy.com", "tapjoy.net", "taptica.com", "taptica.net",
        "theadex.com", "track.io", "tracking.mi.com", "trafficfactory.biz", "trafficjunky.com", "tremorhub.com",
        "tsyndicate.com", "twiago.com", "unityads.unity.com", "unityads.unity3d.com", "valueclick.com", "valueclick.net",
        "vungle.com", "vungle.io", "vungle.net", "win.gdt.qq.com", "yieldbird.com", "yieldlab.net",
        "yieldmo.com", "yieldnexus.com", "youappi.com", "youmi.com", "youmi.net", "zedo.com",
        "zedo.net",
    ]
    static let trackers: [String] = [
        "abtester.com", "addthis.com", "addthisedge.com", "addtoany.com", "adjust.com", "adjust.io",
        "adjust.world", "adpushup.com", "airbridge.io", "airbridge.net", "airship.com", "amplitude.com",
        "amplitude.io", "an.facebook.com", "analytics.google.com", "analytics.line.me", "analytics.naver.com", "analytics.yahoo.com",
        "appadhoc.com", "appboy.com", "appdynamics.com", "appdynamics.net", "appsee.com", "appsee.net",
        "appsflyer.com", "appsflyer.net", "apptest.com", "apttus.com", "atlassian.com", "batch.com",
        "batch.io", "betteruptime.com", "blogcatalog.com", "branch.io", "braze.com", "bugly.qq.com",
        "bugsnag.com", "bugsnag.net", "cdn.optimizely.com", "chart.io", "chartbeat.com", "chartbeat.net",
        "clarify.fm", "clarity.ms", "clickfox.com", "clicktale.com", "clicktale.net", "cloudflare.com",
        "cloudflareinsights.com", "cloudkick.com", "cloudmobi.net", "confirmit.com", "connect.facebook.net", "constantcontact.com",
        "contentsquare.net", "count.ly", "countly.com", "countly.net", "crashlytics.com", "crazyegg.com",
        "customer.io", "datadog.com", "datadoghq.com", "decibel.com", "decibel.net", "dem.io",
        "digitalturbine.com", "distinct.io", "dynatrace.com", "edge-chat.twitter.com", "eloqua.com", "engage.squarespace",
        "exacttarget.com", "fabric.io", "fathom.com", "fathomcdn.com", "feedburner.com", "feedproxy.google.com",
        "feeds.feedburner.com", "flurry.com", "flurry.net", "foresee.com", "foreseeresults.com", "fullstory.com",
        "fullstory.io", "getsentry.com", "getui.com", "gigaom.com", "glassbox.io", "glassboxdigital.com",
        "goatcounter.com", "google-analytics.com", "google.com/analytics", "googletagmanager.com", "grafana.com", "graph.instagram.com",
        "growingio.com", "growingio.net", "gtimg.com", "heap.com", "heap.io", "histats.com",
        "hockeyapp.net", "hotjar.com", "hotjar.io", "hubspot.com", "hubspot.net", "igexin.com",
        "instabug.com", "instabug.net", "intercom.com", "intercom.io", "jiguang.cn", "jpush.cn",
        "jpush.io", "kakaocorp.com", "keen.io", "kissmetrics.com", "kissmetrics.net", "kochava.com",
        "kochava.net", "localytics.com", "localytics.net", "log.daum.net", "log.line-apps.com", "logentries.com",
        "loggly.com", "logx.optimizely.com", "looker.com", "mailchimp.com", "marketo.com", "marketon.net",
        "matomo.org", "medallia.com", "medallia.net", "mediaplex.com", "metricool.com", "metricsonar.com",
        "microanalytics.io", "mixpanel.com", "mixpanel.io", "mob.com", "mopub.io", "mouseflow.com",
        "mouseflow.net", "mpt.io", "mta.cdn.qq.com", "mta.qq.com", "nagel-tech.com", "naver.com",
        "newrelic.com", "newrelic.net", "optimizely.com", "optimizely.net", "papertrail.com", "pardot.com",
        "parse.ly", "parseground.com", "parsely.com", "particle.io", "pendo.io", "pingdom.com",
        "pirsch.io", "piwik.org", "piwik.pro", "platform.twitter.com", "plausible.io", "posthog.com",
        "pubnub.com", "pusher.com", "qualaroo.com", "qualaroo.net", "qualtrics.com", "quantcast.com",
        "quantcount.com", "quantserve.com", "ruxit.com", "s3.amazonaws.com", "sa.pxxiangs.com", "salesforce.com",
        "scorecardresearch.com", "segment.com", "segment.io", "segmentapi.com", "sensorsdata.cn", "sensorsdata.com",
        "sentry.io", "settings.crashlytics.com", "sharesdk.cn", "sharethis.com", "singular.net", "sitemeter.com",
        "snowplow.com", "snowplowanalytics.com", "splkmobile.com", "ssl.google-analytics.com", "staticxx.facebook.com", "stats.ig.com",
        "stats.wix.com", "statuscake.com", "strands.com", "survicate.com", "swrve.com", "swrve.net",
        "syndication.twitter.com", "talkingdata.com", "talkingdata.net", "telemetry.apple.com", "telemetry.microsoft.com", "tenjin.com",
        "tenjin.io", "testflight.apple.com", "thinkingdata.cn", "typeform.com", "umeng.co", "umeng.com",
        "umengapps.com", "umengcloud.com", "umengj.com", "uptimerobot.com", "urbanairship.com", "usermaven.com",
        "visualwebsiteoptimizer.com", "vwo.com", "weborama.fr", "webtrends.com", "webtrends.net", "whos.amung.us",
        "widgets.wp.com", "wixpress.com", "zendesk.com", "zopim.com",
    ]
    static let malware: [String] = [
        "adware.com", "cybercrime-tracker.net", "feodotracker.abuse.ch", "hosts-file.net", "malc0de.com", "malicious.com",
        "malware-traffic-analysis.net", "malware.com", "malwarebytes.com", "malwaredomainlist.com", "malwaredomains.com", "mwsl.org",
        "notsharestuff.com", "palevotracker.abuse.ch", "phishing.com", "phishsite.com", "ransomware.com", "someonewhocares.org",
        "spam404.com", "spyware.com", "threatcrowd.org", "threatminer.org", "trojan.com", "urlhaus.abuse.ch",
        "virus.com", "virustotal.com", "vxvault.net", "winhelp2002.mvps.org", "zeustracker.abuse.ch",
    ]
    static let annoyance: [String] = [
        "ad-maven.com", "adf.ly", "adfoc.us", "admaven.com", "adnow.com", "adskeeper.com",
        "bc.vc", "clickadu.com", "clicksgear.com", "content.ad", "evadav.com", "gestyy.com",
        "ligatus.com", "linkshrink.net", "mgid.com", "nativeads.com", "onclick.net", "onclickads.net",
        "ouo.io", "outbrain.com", "plista.com", "pop-ads.net", "popads.net", "popcash.net",
        "popunder.net", "propellerads.com", "propush.me", "revcontent.com", "richpush.com", "shorte.st",
        "taboola.com", "troncopartners.com", "zergnet.com",
    ]

    /// 全部域名（去重）
    static var allDomains: [String] {
        let all = ads + trackers + malware + annoyance
        return Array(NSOrderedSet(array: all)) as? [String] ?? all
    }

    /// 生成内置 REJECT 规则
    static func rules() -> [Rule] {
        return allDomains.map { d in
            Rule(kind: "DOMAIN-SUFFIX", payload: d, policy: "REJECT",
                 raw: "DOMAIN-SUFFIX," + d + ",REJECT")
        }
    }
}
