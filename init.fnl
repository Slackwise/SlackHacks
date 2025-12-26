(local Self (: (LibStub "AceAddon-3.0") :NewAddon "SlackwiseTweaks"
               "AceConsole-3.0" "AceEvent-3.0"))
(set Self.config (LibStub :AceConfig-3.0))
(set Self.frame (CreateFrame :Frame :SlackwiseTweaks))
(set Self.itemBindingFrame
     (CreateFrame :Frame "SlackwiseTweaks Item Bindings"))
(set _G.SlackwiseTweaks Self)
(set Self.Self Self)
(setmetatable Self {:__index _G})
(setfenv 1 Self)
(global (addon-name addon-table) ...)
(global db-defaults
        {:global {:isDebugging false :log {}}
         :profile {:mounts {:ground nil
                            :ground-passenger nil
                            :ground-passenger-showoff nil
                            :ground-showoff nil
                            :skyriding nil
                            :skyriding-passenger nil
                            :skyriding-passenger-showoff nil
                            :skyriding-showoff nil
                            :steadyflight nil
                            :steadyflight-passenger nil
                            :steadyflight-passenger-showoff nil
                            :steadyflight-showoff nil
                            :water nil
                            :water-showoff nil}}})
(fn get-battletag [] (select 2 (BNGetInfo)))
(fn is-slackwise []
  (= (get-battletag) "Slackwise#1121"))
(fn is-tester [] (is-slackwise))
(fn is-retail [] (= WOW_PROJECT_ID WOW_PROJECT_MAINLINE))
(fn is-classic [] (= WOW_PROJECT_ID WOW_PROJECT_CLASSIC))
(fn get-game-type []
  (if (is-retail) :RETAIL
      (is-classic) :CLASSIC
      :UNKNOWN))
(fn is-debugging []
  (if (is-initialized)
    Self.db.global.isDebugging
    (is-slackwise)))
(global COLOR_START :|c)
(global COLOR_END :|r)
(fn color [color] (fn [text] (.. COLOR_START :FF color text COLOR_END)))
(global grey (color :AAAAAA))
(fn log [message ...]
  (when (is-debugging)
    (print (.. (grey (date)) "  " message))
    (when (is-initialized)
      (table.insert Self.db.global.log (.. (date) "  " message))
      (when arg
        (each [i v (ipairs arg)] (print (.. "Arg " i " = " v))
          (table.insert Self.db.global.log (.. "Arg " i " = " v)))))))
(fn Self.OnInitialize [self]
  (set Self.db (: (Lib-stub :AceDB-3.0) :New :SlackwiseTweaksDB db-defaults))
  (config:RegisterOptionsTable :SlackwiseTweaks options :slack)
  (set Self.configDialog (: (Lib-stub :AceConfigDialog-3.0) :AddToBlizOptions
                            :SlackwiseTweaks)))
(fn is-initialized []
  (not (not (. Self :configDialog))))	