import re
import time
import BasePlayer
from UnityEngine import Vector3
from System import Action

DEV = False
LATEST_CFG = 1.0
LINE = '-' * 50

class RankME:

    def __init__(self):

        self.Title = 'Rank-ME'
        self.Version = V(1, 0, 1)
        self.Author = 'SkinN'
        self.Description = 'Simple ranking system based on player statistics'
        self.ResourceId = 1074

    # --------------------------------------------------------------------------
    def Init(self):

        self.console(LINE)

        # CONFIGURATION
        if self.Config['CONFIG_VERSION'] < LATEST_CFG or DEV:
            self.UpdateConfig()

        global MSG, PLUGIN, COLOR, STRINGS
        MSG, COLOR, PLUGIN, STRINGS = [self.Config[x] for x in ('MESSAGES','COLORS','SETTINGS', 'STRINGS')]

        self.prefix = '<%s>%s<end>' % (COLOR['PREFIX'], PLUGIN['PREFIX']) if PLUGIN['PREFIX'] else None
        self.dbname = 'rankme_db'
        self.keys = ('KILLS', 'DEATHS', 'KDR', 'SUICIDES', 'SUICIDE RATIO', 'ANIMALS', 'RANGE', 'SLEEPERS')
        self.cache = {}

        # LOAD DATABASE
        self.db = data.GetData(self.dbname)

        # CHECK ACTIVE PLAYERS
        for player in self.playerlist():
            self.check_player(player)
        self.console('* Loading database and verifying players.')

        # START AUTO-SAVE LOOP
        mins = PLUGIN['AUTO-SAVE INTERVAL']
        if mins:
            secs = mins * 60 if mins else 60
            self.adverts_loop = timer.Repeat(secs, 0, Action(self.save_data), self.Plugin)
            self.console('* Starting Auto-Save loop, set to %s minute/s' % mins)
        else:
            self.autosave_interval = None
            self.console('* Auto-Save is disabled')

        # COMMANDS
        self.cmds = []
        for cmd in [x for x in self.Config['COMMANDS'].keys()]:
            if PLUGIN['ENABLE %s CMD' % cmd]:
                self.cmds.append(cmd)
                command.AddChatCommand(self.Config['COMMANDS'][cmd], self.Plugin, '%s_CMD' % cmd.replace(' ', '_').lower())

        self.console('* Enabling commands:')
        if self.cmds:
            for cmd in self.cmds:
                self.console('  - /%s (%s)' % (self.Config['COMMANDS'][cmd], cmd.title()))
        else: self.console('  - No commands enabled')

        command.AddConsoleCommand('rankme.savedb', self.Plugin, 'save_data')
        command.AddConsoleCommand('rankme.wipedb', self.Plugin, 'console_wipe_CMD')
        command.AddChatCommand('rankme', self.Plugin, 'plugin_CMD')

        self.console(LINE)

    # --------------------------------------------------------------------------
    def Unload(self):

        # SAVE DATABASE
        self.save_data()

    # ==========================================================================
    # <>> CONFIGURATION
    # ==========================================================================
    def LoadDefaultConfig(self):

        self.Config = {
            'CONFIG_VERSION': LATEST_CFG,
            'SETTINGS': {
                'PREFIX': self.Title,
                'BROADCAST TO CONSOLE': True,
                'AUTO-SAVE INTERVAL': 10,
                'DATABASE RESET AUTHLEVEL': 2,
                'DATABASE SAVE AUTHLEVEL': 1,
                'TOP MAX PLAYERS': 10,
                'SHOW TOP IN CHAT': True,
                'SHOW TOP IN CONSOLE': False,
                'SHOW RANK IN CHAT': True,
                'SHOW RANK IN CONSOLE': False,
                'ANNOUNCE DATABASE WIPE': True,
                'ENABLE SAVE DATA CMD': True,
                'ENABLE WIPE DATA CMD': True,
                'ENABLE PLAYERS RESET CMD': True,
                'ENABLE RANK CMD': True,
                'ENABLE TOP CMD': True,
            },
            'MESSAGES': {
                'DATA SAVED': 'Database has been saved.',
                'DATABASE WIPED': 'Database has been wiped.',
                'PLAYER RESETED': 'Your rank has been reseted.',
                'RANK INFO': 'Your Ranking Info',
                'NOT RANKED': 'Not ranked yet!',
                'TOP TITLE': 'Top {list}',
                'CHECK CONSOLE NOTE': 'Check the console (press F1) for more info.',
                'TOP DESC': '/top <orange><list><end> - <lime>Shows the top kills list, or any other list like deaths, kdr, etc.<end>',
                'RANK DESC': '/rank - <lime>Shows your rank information<end>',
                'PLAYERS RESET DESC': '/resetme - <lime>Resets your rank<end>',
                'WIPE DATA DESC': '/wipedb - <lime>Resets the ranking database, and starts a new one. (Admins Only)<end>',
                'SAVE DATA DESC': '/savedb - <lime>Saves the database. (Admins Only)<end>',
                'HELP DESC': '<orange>Rank-ME<end> <white>-<end> Type <white>/rankme help<end> for all available commands.',
                'AVAILABLE COMMANDS': 'Available Commands',
                'LIST NOT FOUND': 'List not found. Here are the available lists:',
                'NO PLAYERS TO LIST': 'There aren\'t yet players with positive values to show the {list} list.'
            },
            'STRINGS': {
                'NO ACCESS': 'Access Restricted.',
                'RANK': 'Rank Position',
                'NAME': 'Name',
                'KILLS': 'Player Kills',
                'DEATHS': 'Deaths',
                'KDR': 'Kill/Death Ratio',
                'SUICIDES': 'Suicides',
                'SUICIDE RATIO': 'Suicide Ratio',
                'ANIMALS': 'Animal Kills',
                'RANGE': 'Range',
                'SLEEPERS': 'Sleepers'
            },
            'COLORS': {
                'PREFIX': 'orange',
                'SYSTEM': 'lime'
            },
            'COMMANDS': {
                'SAVE DATA': 'savedb',
                'WIPE DATA': 'wipedb',
                'PLAYERS RESET': 'resetme',
                'RANK': 'rank',
                'TOP': 'top'
            },
        }

        self.console('* Loading default configuration file', True)

    # --------------------------------------------------------------------------
    def UpdateConfig(self):

        # IS OLDER CONFIG TOO OLD?
        if self.Config['CONFIG_VERSION'] <= LATEST_CFG - 0.2 or DEV:

            self.console('* Current configuration file is two or more versions older than the latest (Current: v%s / Latest: v%s)' % (self.Config['CONFIG_VERSION'], LATEST_CFG), True)

            # RESET CONFIGURATION
            self.Config.clear()

            # LOAD DEFAULTS CONFIGURATION
            self.LoadDefaultConfig()

        else:

            self.console('* Applying new changes to the configuration file (Version: %s)' % LATEST_CFG, True)

            # NEW VERSION VALUE
            self.Config['CONFIG_VERSION'] = LATEST_CFG

            # NEW CHANGES
            self.Config['STRINGS']['RANGE'] = self.Config['STRINGS']['LONGEST SHOT']
            del self.Config['STRINGS']['LONGEST SHOT']

        # SAVE CHANGES
        self.SaveConfig()

    # --------------------------------------------------------------------------
    def save_data(self, args=None):

        data.SaveData(self.dbname)
        self.console('Saving database')

    # --------------------------------------------------------------------------
    def reset_data(self):

        if self.db: self.db.clear()
        self.console('Reseting database')
        self.save_data()
        for player in self.playerlist():
            self.check_player(player)

    # ==========================================================================
    # <>> MESSAGE FUNTIONS
    # ==========================================================================
    def console(self, text, force=False):

        if self.Config['SETTINGS']['BROADCAST TO CONSOLE'] or force:
            print('[%s v%s] :: %s' % (self.Title, str(self.Version), self._format(text, True)))

    # --------------------------------------------------------------------------
    def pconsole(self, player, text, color='white'):

        player.SendConsoleCommand(self._format('echo <%s>%s<end>' % (color, text)))

    # --------------------------------------------------------------------------
    def say(self, text, color='white', userid=0, force=True):

        if self.prefix and force:
            rust.BroadcastChat(self._format('<yellow>[ %s ]<end> <%s>%s<end>' % (self.prefix, color, text)), None, str(userid))
        else:
            rust.BroadcastChat(self._format('<%s>%s<end>' % (color, text)), None, str(userid))
        self.console(self._format(text, True))

    # --------------------------------------------------------------------------
    def tell(self, player, text, color='white', userid=0, force=True):

        if self.prefix and force:
            rust.SendChatMessage(player, self._format('<yellow>[ %s ]<end> <%s>%s<end>' % (self.prefix, color, text)), None, str(userid))
        else:
            rust.SendChatMessage(player, self._format('<%s>%s<end>' % (color, text)), None, str(userid))

    # --------------------------------------------------------------------------
    def _format(self, text, con=False):

        colors = (
            'red', 'blue', 'green', 'yellow', 'white', 'black', 'cyan',
            'lightblue', 'lime', 'purple', 'darkblue', 'magenta', 'brown',
            'orange', 'olive', 'gray', 'grey', 'silver', 'maroon'
        )

        name = r'\<(\w+)\>'
        hexcode = r'\<(#\w+)\>'
        end = '<end>'

        if con:
            for x in (end, name, hexcode):
                if x.startswith('#') or x in colors:
                    text = re.sub(x, '', text)
        else:
            text = text.replace(end, '</color>')
            for f in (name, hexcode):
                for c in re.findall(f, text):
                    if c.startswith('#') or c in colors:
                        text = text.replace('<%s>' % c, '<color=%s>' % c)
        return text

    # ==========================================================================
    # <>> PLAYER HOOKS
    # ==========================================================================
    def OnPlayerInit(self, player):

        self.check_player(player)

    # ==========================================================================
    # <>> PLAYER HOOKS
    # ==========================================================================
    def OnEntityDeath(self, victim, hitinfo):

        ini = hitinfo.Initiator if hitinfo else None
        att_ent = ini if ini and ini.ToPlayer() else None

        if victim and victim.ToPlayer():

            dmg = str(victim.lastDamage).upper()
            vic_sid = self.playerid(victim)
            vic_dic = self.db[vic_sid]

            if dmg == 'SUICIDE':

                vic_dic['SUICIDES'] += 1
                if vic_dic['DEATHS']:
                    vic_dic['SUICIDE RATIO'] = self.sfloat(float(vic_dic['SUICIDES']) / vic_dic['DEATHS'])

            elif att_ent and dmg in ('SLASH', 'BLUNT', 'STAB', 'BULLET', 'BITE'):

                att_sid = self.playerid(att_ent)
                att_dic = self.db[att_sid]

                if victim.IsSleeping():
                    att_dic['SLEEPERS'] += 1
                else:
                    att_dic['KILLS'] += 1

                if att_dic['DEATHS']:
                    att_dic['KDR'] = self.sfloat(float(att_dic['KILLS']) / att_dic['DEATHS'])

                d = float('%2f' % Vector3.Distance(victim.transform.position, att_ent.transform.position))
                if d > att_dic['RANGE']:
                    att_dic['RANGE'] = d

                self.db[att_sid].update(att_dic)

            vic_dic['DEATHS'] += 1
            if vic_dic['DEATHS']:
                vic_dic['KDR'] = self.sfloat(float(vic_dic['KILLS']) / vic_dic['DEATHS'])

            self.db[vic_sid].update(vic_dic)

        elif victim and 'animals' in str(victim) and att_ent:

            att_sid = self.playerid(att_ent)
            att_dic = self.db[att_sid]

            att_dic['ANIMALS'] += 1
            d = float('%.2f' % Vector3.Distance(victim.transform.position, att_ent.transform.position))
            if d > att_dic['RANGE']:
                att_dic['RANGE'] = d

            self.db[att_sid].update(att_dic)

    # ==========================================================================
    # <>> FUNCTIONS
    # ==========================================================================
    def playerid(self, player):

        return rust.UserIDFromPlayer(player)

    # --------------------------------------------------------------------------
    def playerlist(self):

        return list(BasePlayer.activePlayerList) + list(BasePlayer.sleepingPlayerList)

    # --------------------------------------------------------------------------
    def playerauth(self, player):

        return player.net.connection.authLevel

    # --------------------------------------------------------------------------
    def getsorted(self, l):

        m = PLUGIN['TOP MAX PLAYERS']
        return sorted(self.db, key=lambda player: self.db[player][l], reverse=True)[:m if m and m < 21 else 10]

    # --------------------------------------------------------------------------
    def sfloat(self, f):

        return float('%.2f' % f)

    # --------------------------------------------------------------------------
    def check_player(self, player, reset=False):

        steamid = self.playerid(player)
        if len(steamid) == 17:
            if steamid not in self.db or reset:
                self.db[steamid] = {
                    'NAME': player.displayName,
                    'KILLS': 0,
                    'DEATHS': 0,
                    'KDR': 0.0,
                    'SUICIDES': 0,
                    'SUICIDE RATIO': 0.0,
                    'ANIMALS': 0,
                    'RANGE': 0.0,
                    'SLEEPERS': 0
                }
            else:
                a = self.db[steamid]
                a['NAME'] = player.displayName
                if 'LONGEST SHOT' in a:
                    a['RANGE'] = a['LONGEST SHOT']
                    del a['LONGEST SHOT']
                if 'STEAMID' in a:
                    del a['STEAMID']
                self.db[steamid].update(a)

    # ==========================================================================
    # <>> COMMANDS
    # ==========================================================================
    def save_data_CMD(self, player, cmd, args):

        if self.playerauth(player) >= PLUGIN['DATABASE SAVE AUTHLEVEL']:
            self.save_data()
            self.tell(player, MSG['DATA SAVED'], COLOR['SYSTEM'])
        else: self.tell(player, MSG['NO ACCESS'], COLOR['SYSTEM'])

    # --------------------------------------------------------------------------
    def wipe_data_CMD(self, player, cmd, args):

        if self.playerauth(player) >= PLUGIN['DATABASE RESET AUTHLEVEL']:
            self.reset_data()
            if PLUGIN['ANNOUNCE DATABASE WIPE']:
                for x in BasePlayer.activePlayerList:
                    self.tell(x, MSG['DATABASE WIPED'], COLOR['SYSTEM'])
        else: self.tell(player, MSG['NO ACCESS'], COLOR['SYSTEM'])

    # --------------------------------------------------------------------------
    def console_wipe_CMD(self, args):

        self.reset_data()
        if PLUGIN['ANNOUNCE DATABASE WIPE']:
            for x in BasePlayer.activePlayerList:
                self.tell(x, MSG['DATABASE WIPED'], COLOR['SYSTEM'])

    # --------------------------------------------------------------------------
    def players_reset_CMD(self, player, cmd, args):

        del self.db[self.playerid(player)]
        self.check_player(player)
        self.say(MSG['PLAYER RESETED'], COLOR['SYSTEM'])

    # --------------------------------------------------------------------------
    def rank_CMD(self, player, cmd, args):

        steamid = self.playerid(player)
        target = self.db[steamid]
        rank = 0
        for a, b in enumerate(self.getsorted('KILLS')):
            if b == steamid:
                rank = a + 1
        l = [
            '<orange>%s<end> | %s:' % (self.prefix, MSG['RANK INFO']),
            LINE
        ]
        if target['KILLS']:
           l.append('<yellow>%s:<end> <lime>%s / %s<end>' % (STRINGS['RANK'], rank, len(self.db)))
        else:
            l.append(('%s : <red>%s<end>' % (STRINGS['RANK'], MSG['NOT RANKED'])))
        for i in self.keys:
            l.append(('%s : <yellow>%s<end>' % (STRINGS[i], target[i])))
        for i in l:
            if PLUGIN['SHOW RANK IN CHAT']:
                if isinstance(i, tuple):
                    self.tell(player, *i, force=False)
                else:
                    self.tell(player, i, force=False)
            if PLUGIN['SHOW RANK IN CONSOLE']:
                if isinstance(i, tuple):
                    self.pconsole(player, *i)
                else:
                    self.pconsole(player, i)
        if PLUGIN['SHOW RANK IN CONSOLE']:
            self.pconsole(player, LINE)
            self.tell(player, LINE, force=False)
            self.tell(player, MSG['CHECK CONSOLE NOTE'], COLOR['SYSTEM'], force=False)
        self.tell(player, LINE, force=False)

    # --------------------------------------------------------------------------
    def top_CMD(self, player, cmd, args):

        key = 'KILLS'
        if args:
            args = ' '.join(args).upper()
            if args in self.keys:
                key = args
            else:
                self.tell(player, MSG['LIST NOT FOUND'], COLOR['SYSTEM'])
                self.tell(player, ', '.join(['<lime>%s<end>' % x.lower() for x in self.keys]))
                return
        l = self.getsorted(key)
        l = [x for x in l if self.db[x][key]]
        if l:
            lines = [
                '%s | %s:' % (self.prefix, MSG['TOP TITLE'].format(list=STRINGS[key])),
                LINE
            ]
            for n, p in enumerate(l):
                i = self.db[p]
                lines.append(('<orange>%s.<end> %s: <lime>%s<end>' % (n+1, i['NAME'], i[key]), p))
            lines.append(LINE)
            if PLUGIN['SHOW TOP IN CONSOLE']:
                for i in lines:
                    if isinstance(i, tuple):
                        a, b = i
                        self.pconsole(player, a)
                    else:
                        self.pconsole(player, i)
            if PLUGIN['SHOW TOP IN CHAT']:
                if PLUGIN['SHOW TOP IN CONSOLE']:
                    lines.append('<%s>%s<end>' % (COLOR['SYSTEM'], MSG['CHECK CONSOLE NOTE']))
                    lines.append(LINE)
                for i in lines:
                    if isinstance(i, tuple):
                        a, b = i
                        self.tell(player, a, 'white', b, False)
                    else:
                        self.tell(player, i, force=False)
        else:
            self.tell(player, MSG['NO PLAYERS TO LIST'].format(list=STRINGS[key]), COLOR['SYSTEM'])

    # --------------------------------------------------------------------------
    def plugin_CMD(self, player, cmd, args):

        if args and 'help' in args:
            self.tell(player, '<orange>%s<end> | %s:' % (self.Title, MSG['AVAILABLE COMMANDS']), force=False)
            self.tell(player, LINE, force=False)
            for cmd in self.Config['COMMANDS']:
                self.tell(player, MSG['%s DESC' % cmd], 'yellow', force=False)
            self.tell(player, LINE, force=False)
        else:
            self.tell(player, LINE, force=False)
            self.tell(player, '<red>%s<end> <lime>v%s <white>by<end> SkinN<end>' % (self.Title.upper(), self.Version), force=False)
            self.tell(player, self.Description, 'lime', force=False)
            self.tell(player, '| RESOURSE ID: <lime>%s<end> | CONFIG: v<lime>%s<end> |' % (self.ResourceId, self.Config['CONFIG_VERSION']), force=False)
            self.tell(player, LINE, force=False)
            self.tell(player, '<< Click the icon to contact me.', userid='76561197999302614', force=False)

    # ==========================================================================
    # <>> MISC FUNTIONS
    # ==========================================================================
    def SendHelpText(self, player):

        self.tell(player, MSG['HELP DESC'], COLOR['SYSTEM'], force=False)

# ==============================================================================