/*
 * TNSampleTabModule.j
 *
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "TNRolesController.j"
@import "TNXMPPUserDatasource.j"

TNArchipelTypePermissions        = @"archipel:permissions";

TNArchipelTypePermissionsList   = @"list";
TNArchipelTypePermissionsGet    = @"get";
TNArchipelTypePermissionsSet    = @"set";
TNArchipelTypePermissionsGetOwn = @"getown";
TNArchipelTypePermissionsSetOwn = @"setown";

TNArchipelPushNotificationPermissions   = @"archipel:push:permissions";

var TNArchipelTypeXMPPServerUsers                   = @"archipel:xmppserver:users",
    TNArchipelTypeXMPPServerUsersList               = @"list";

/*! @defgroup  permissionsmodule Module Permissions
    @desc This module allow to manages entity permissions
*/

/*! @ingroup permissionsmodule
    Permission module implementation
*/
@implementation TNPermissionsController : TNModule
{
    @outlet CPButtonBar             buttonBarControl;
    @outlet CPScrollView            scrollViewPermissions;
    @outlet CPSearchField           filterField;
    @outlet CPTextField             fieldJID                @accessors;
    @outlet CPTextField             fieldName               @accessors;
    @outlet CPView                  viewTableContainer;
    @outlet TNRolesController       rolesController;
    @outlet CPScrollView            scrollViewUsers;
    @outlet CPSplitView             splitView;

    CPArray                         _currentUserPermissions;
    CPButton                        _applyRoleButton;
    CPButton                        _saveAsTemplateButton;
    CPButton                        _saveButton;
    CPImage                         _defaultAvatar;
    CPTableView                     _tablePermissions;
    TNTableViewDataSource           _datasourcePermissions  @accessors(getter=datasourcePermissions);
    TNXMPPUserDatasource            _datasourceUsers;
    CPOutlineView                   _outlineViewUsers;
}


#pragma mark -
#pragma mark Initialization

/*! called at cib awakening
*/
- (void)awakeFromCib
{
    [fieldJID setSelectable:YES];

    _currentUserPermissions = [CPArray array];
    _defaultAvatar          = [[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"user-unknown.png"]];

    [splitView setBorderedWithHexColor:@"#C0C7D2"];

    [viewTableContainer setHidden:YES];

    _datasourcePermissions  = [[TNTableViewDataSource alloc] init];
    _tablePermissions       = [[CPTableView alloc] initWithFrame:[scrollViewPermissions bounds]];

    [scrollViewPermissions setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [scrollViewPermissions setAutohidesScrollers:YES];
    [scrollViewPermissions setDocumentView:_tablePermissions];

    [_tablePermissions setUsesAlternatingRowBackgroundColors:YES];
    [_tablePermissions setAutoresizingMask: CPViewWidthSizable | CPViewHeightSizable];
    [_tablePermissions setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
    [_tablePermissions setAllowsColumnReordering:YES];
    [_tablePermissions setAllowsColumnResizing:YES];
    [_tablePermissions setAllowsEmptySelection:YES];


    var colName         = [[CPTableColumn alloc] initWithIdentifier:@"name"],
        colDescription  = [[CPTableColumn alloc] initWithIdentifier:@"description"],
        colValue        = [[CPTableColumn alloc] initWithIdentifier:@"state"],
        checkBoxView    = [CPCheckBox checkBoxWithTitle:@""];

    [colName setWidth:125];
    [[colName headerView] setStringValue:@"Name"];

    [colDescription setWidth:450];
    [[colDescription headerView] setStringValue:@"Description"];

    [colValue setWidth:30];
    [[colValue headerView] setStringValue:@""];

    [checkBoxView setAlignment:CPCenterTextAlignment];
    [checkBoxView setFrameOrigin:CPPointMake(10.0, 0.0)];
    [checkBoxView setTarget:self];
    [checkBoxView setAction:@selector(changePermissionsState:)];
    [colValue setDataView:checkBoxView];

    [_tablePermissions addTableColumn:colValue];
    [_tablePermissions addTableColumn:colName];
    [_tablePermissions addTableColumn:colDescription];

    [_datasourcePermissions setTable:_tablePermissions];
    [_datasourcePermissions setSearchableKeyPaths:[@"name", @"description"]];
    [_tablePermissions setDataSource:_datasourcePermissions];

    _saveButton = [CPButtonBar plusButton];
    [_saveButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/save.png"] size:CPSizeMake(16, 16)]];
    [_saveButton setTarget:self];
    [_saveButton setAction:@selector(changePermissionsState:)];
    [_saveButton setToolTip:@"Save the current set of permissions"];

    _saveAsTemplateButton = [CPButtonBar plusButton];
    [_saveAsTemplateButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/role_add.png"] size:CPSizeMake(16, 16)]];
    [_saveAsTemplateButton setTarget:rolesController];
    [_saveAsTemplateButton setAction:@selector(openNewTemplateWindow:)];
    [_saveAsTemplateButton setToolTip:@"Save the current set of permissions as a role"];

    _applyRoleButton = [CPButtonBar plusButton];
    [_applyRoleButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/roles.png"] size:CPSizeMake(16, 16)]];
    [_applyRoleButton setTarget:self];
    [_applyRoleButton setAction:@selector(openRolesWindow:)];
    [_applyRoleButton setToolTip:@"Select a role as permissions template"];

    [buttonBarControl setButtons:[_saveButton, _saveAsTemplateButton, _applyRoleButton]];


    [filterField setTarget:_datasourcePermissions];
    [filterField setAction:@selector(filterObjects:)];

    [rolesController setDelegate:self];

    [scrollViewUsers setAutohidesScrollers:YES];

    _outlineViewUsers = [[CPOutlineView alloc] initWithFrame:[scrollViewUsers bounds]];
    _datasourceUsers = [[TNXMPPUserDatasource alloc] init];

    [_outlineViewUsers setCornerView:nil];
    [_outlineViewUsers setAllowsColumnResizing:YES];
    [_outlineViewUsers setUsesAlternatingRowBackgroundColors:YES];
    [_outlineViewUsers setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
    [_outlineViewUsers setDataSource:_datasourceUsers];
    [_outlineViewUsers setBackgroundColor:[CPColor blueColor]];
    [scrollViewUsers setDocumentView:_outlineViewUsers];
    var columnName  = [[CPTableColumn alloc] initWithIdentifier:@"description"];
    [[columnName headerView] setStringValue:@"Users"];
    [_outlineViewUsers setOutlineTableColumn:columnName];
    [_outlineViewUsers addTableColumn:columnName];
    [_outlineViewUsers reloadData];
}


#pragma mark -
#pragma mark TNModule overrides

/*! called when module is loaded
*/
- (BOOL)willLoad
{
    [super willLoad];
    [_datasourceUsers flush];
    [_outlineViewUsers setDelegate:self];

    var center = [CPNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_didUpdateNickName:) name:TNStropheContactNicknameUpdatedNotification object:_entity];
    [center postNotificationName:TNArchipelModulesReadyNotification object:self];

    [self registerSelector:@selector(_didReceivePush:) forPushNotificationType:TNArchipelPushNotificationPermissions];

    for (var i = 0; i < [[[[TNStropheIMClient defaultClient] roster] contacts] count]; i++)
    {
        var contact = [[[[TNStropheIMClient defaultClient] roster] contacts] objectAtIndex:i];

        if ([[[TNStropheIMClient defaultClient] roster] analyseVCard:[contact vCard]] == TNArchipelEntityTypeUser)
            [_datasourceUsers addRosterUser:[contact JID]];
    }

    [self getXMPPUsers];
}

/*! called when module becomes visible
*/
- (BOOL)willShow
{
    if (![super willShow])
        return NO;

    [fieldName setStringValue:[_entity nickname]];
    [fieldJID setStringValue:[_entity JID]];

    return YES;
}

/*! called when module is unloaded
*/
- (void)willUnload
{
    [_datasourcePermissions removeAllObjects];
    [_tablePermissions reloadData];

    [super willUnload];
}

/*! called when permissions changes
*/
- (void)permissionsChanged
{
    if (![self currentEntityHasPermission:@"permission_get"])
        [self changeCurrentUser:nil];

    var hasSetOwn   = [self currentEntityHasPermission:@"permission_setown"],
        hasSet      = [self currentEntityHasPermission:@"permission_set"];

    if (hasSet || hasSetOwn)
    {
        if (hasSetOwn)
            [self setControl:_saveButton enabledAccordingToPermission:@"permission_setown"];
        if (hasSet)
            [self setControl:_saveButton enabledAccordingToPermission:@"permission_set"];
    }
    else
        [self setControl:_saveButton enabledAccordingToPermission:@"permission_FAKE!"];
}


#pragma mark -
#pragma mark Notification handlers

/*! called when entity' nickname changed
    @param aNotification the notification
*/
- (void)_didUpdateNickName:(CPNotification)aNotification
{
    if ([aNotification object] == _entity)
    {
       [fieldName setStringValue:[_entity nickname]]
    }
}

/*! called when an Archipel push is received
    @param somePushInfo CPDictionary containing the push information
*/
- (BOOL)_didReceivePush:(CPDictionary)somePushInfo
{
    var sender  = [somePushInfo objectForKey:@"owner"],
        type    = [somePushInfo objectForKey:@"type"],
        change  = [somePushInfo objectForKey:@"change"],
        date    = [somePushInfo objectForKey:@"date"];

    CPLog.info(@"PUSH NOTIFICATION: from: " + sender + ", type: " + type + ", change: " + change);

    [self changeCurrentUser:nil];

    return YES;
}


#pragma mark -
#pragma mark Utilities

/*! will select all permissions given (and deselect others)
    @param somePermissions CPArray containing a list raw Archipel permissions (TNXMLNodes)
*/
- (void)applyPermissions:(CPArray)somePermissions
{
    for (var j = 0; j < [_datasourcePermissions count]; j++)
    {
        var perm = [_datasourcePermissions objectAtIndex:j];
        [perm setValue:CPOffState forKey:@"state"];
    }

    [self addPermissions:somePermissions];
}

/*! will add all permissions given (keeping existing)
    @param somePermissions CPArray containing a list raw Archipel permissions (TNXMLNodes)
*/
- (void)addPermissions:(CPArray)somePermissions
{
    for (var i = 0; i < [somePermissions count]; i++)
    {
        var permTemplate = [somePermissions objectAtIndex:i];

        for (var j = 0; j < [_datasourcePermissions count]; j++)
        {
            var perm = [_datasourcePermissions objectAtIndex:j];
            if ([perm valueForKey:@"name"] == [permTemplate valueForAttribute:@"permission_name"])
            {
                [perm setValue:CPOnState forKey:@"state"];
                break;
            }
        }
    }

    [_tablePermissions reloadData];
}


/*! will remove all permissions given
    @param somePermissions CPArray containing a list raw Archipel permissions (TNXMLNodes)
*/
- (void)retractPermissions:(CPArray)somePermissions
{
    for (var i = 0; i < [somePermissions count]; i++)
    {
        var permTemplate = [somePermissions objectAtIndex:i];

        for (var j = 0; j < [_datasourcePermissions count]; j++)
        {
            var perm = [_datasourcePermissions objectAtIndex:j];
            if ([perm valueForKey:@"name"] == [permTemplate valueForAttribute:@"permission_name"])
            {
                [perm setValue:CPOffState forKey:@"state"];
                break;
            }
        }
    }

    [_tablePermissions reloadData];
}


#pragma mark -
#pragma mark Actions

/*! will set permissions
    @param aSender the sender of the action
*/
- (IBAction)changePermissionsState:(id)aSender
{
    [self changePermissionsState];
}

/*! will take care of the current user change
    @param aSender the sender of the action
*/
- (IBAction)changeCurrentUser:(id)aSender
{
    if ([_outlineViewUsers numberOfSelectedRows] > 0)
    {
        var selectedIndexes = [_outlineViewUsers selectedRowIndexes],
            object          = [_outlineViewUsers itemAtRow:[selectedIndexes firstIndex]];

        if ([object class] == @"TNStropheJID")
        {
            [viewTableContainer setHidden:NO];
            [self getUserPermissions:[object bare]];
        }
        else if (object == @"Me")
        {
            [viewTableContainer setHidden:NO];
            [self getUserPermissions:[[[TNStropheIMClient defaultClient] JID] bare]];
        }
        else
        {
            [_datasourcePermissions removeAllObjects];
            [_tablePermissions reloadData];
            [viewTableContainer setHidden:YES];
        }
    }
    else
    {
        [_datasourcePermissions removeAllObjects];
        [_tablePermissions reloadData];
        [viewTableContainer setHidden:YES];
    }
}

/*! will open the new role window
    @param aSender the sender of the action
*/
- (IBAction)openRolesWindow:(id)aSender
{
    [rolesController showWindow:aSender];
}


#pragma mark -
#pragma mark XMPP Controls

/*! ask for existing permissions
*/
- (void)getPermissions
{
    if (![self currentEntityHasPermission:@"permission_list"])
        return;

    var stanza = [TNStropheStanza iqWithType:@"get"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypePermissions}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypePermissionsList}];

    [self setModuleStatus:TNArchipelModuleStatusWaiting];
    [_entity sendStanza:stanza andRegisterSelector:@selector(_didReceivePermissions:) ofObject:self];

}

/*! compute the answer containing the permissions
    @param aStanza TNStropheStanza containing the answer
*/
- (void)_didReceivePermissions:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [_datasourcePermissions removeAllObjects];

        var permissions = [aStanza childrenWithName:@"permission"];

        for (var i = 0; i < [permissions count]; i++)
        {
            var permission      = [permissions objectAtIndex:i],
                name            = [permission valueForAttribute:@"name"],
                description     = [permission valueForAttribute:@"description"],
                state           = [_currentUserPermissions containsObject:name] ? CPOnState : CPOffState;
            var newPermission = [CPDictionary dictionaryWithObjectsAndKeys:name, @"name", description, @"description", state, "state"];
            [_datasourcePermissions addObject:newPermission];
        }

        [_tablePermissions reloadData];
        [self setModuleStatus:TNArchipelModuleStatusReady];
    }
    else
    {
        [self setModuleStatus:TNArchipelModuleStatusError];
        [self handleIqErrorFromStanza:aStanza];
    }
}

/*! ask for permissions of given user
    @param aUser the user you want the permissions
*/
- (void)getUserPermissions:(CPString)aUser
{
    if (![self currentEntityHasPermission:@"permission_get"] && ![self currentEntityHasPermission:@"permission_getown"])
        return;

    var stanza = [TNStropheStanza iqWithType:@"get"],
        currentAction = TNArchipelTypePermissionsGetOwn;

    if ([self currentEntityHasPermission:@"permission_get"])
        currentAction = TNArchipelTypePermissionsGet

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypePermissions}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": currentAction,
        "permission_type": "user",
        "permission_target": aUser}];

    [self setModuleStatus:TNArchipelModuleStatusWaiting];
    [_entity sendStanza:stanza andRegisterSelector:@selector(_didReceiveUserPermissions:) ofObject:self];
}

/*! compute the answer containing the user' permissions
    @param aStanza TNStropheStanza containing the answer
*/
- (void)_didReceiveUserPermissions:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var permissions = [aStanza childrenWithName:@"permission"];

        [_currentUserPermissions removeAllObjects];
        for (var i = 0; i < [permissions count]; i++)
        {
            var permission      = [permissions objectAtIndex:i],
                name            = [permission valueForAttribute:@"name"];

            [_currentUserPermissions addObject:name]
        }

        [self getPermissions];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }
}

/*! change the permissions
*/
- (void)changePermissionsState
{
    var stanza = [TNStropheStanza iqWithType:@"set"],
        currentAction = TNArchipelTypePermissionsSetOwn,
        selectedIndexes = [_outlineViewUsers selectedRowIndexes],
        permissionTarget = [_outlineViewUsers itemAtRow:[selectedIndexes firstIndex]];

    if ([self currentEntityHasPermission:@"permission_set"])
        currentAction = TNArchipelTypePermissionsSet

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypePermissions}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        @"action": currentAction}];


    for (var i = 0; i < [_datasourcePermissions count]; i++)
    {
        var perm = [_datasourcePermissions objectAtIndex:i];
        [stanza addChildWithName:@"permission" andAttributes:{
            @"permission_target": permissionTarget,
            @"permission_type": @"user",
            @"permission_name": [perm objectForKey:@"name"],
            @"permission_value": ([perm valueForKey:@"state"] === CPOnState),
        }];
        [stanza up];
    }

    [_entity sendStanza:stanza andRegisterSelector:@selector(_didChangePermissionsState:) ofObject:self];
}

/*! compute the answer containing the result of changing the permissions
    @param aStanza TNStropheStanza containing the answer
*/
- (void)_didChangePermissionsState:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"error")
        [self handleIqErrorFromStanza:aStanza];
}

/*! ask for permissions of given user
*/
- (void)getXMPPUsers
{
    var hypervisors = [CPArray array],
        servers = [CPArray array];

    for (var i = 0; i < [[[[TNStropheIMClient defaultClient] roster] contacts] count]; i++)
    {
        var contact = [[[[TNStropheIMClient defaultClient] roster] contacts] objectAtIndex:i],
            item = [[TNMenuItem alloc] init];

        if (([[[TNStropheIMClient defaultClient] roster] analyseVCard:[contact vCard]] === TNArchipelEntityTypeHypervisor)
            && ([contact XMPPShow] != TNStropheContactStatusOffline)
            && ![hypervisors containsObject:contact]
            && ![servers containsObject:[[contact JID] domain]])
        {
            if (![[TNPermissionsCenter defaultCenter] hasPermission:@"xmppserver_users_list" forEntity:contact])
                continue;
            [servers addObject:[[contact JID] domain]];
            [hypervisors addObject:contact];
        }
    }

    for (var i = 0; i < [hypervisors count]; i++)
    {
        var stanza = [TNStropheStanza iqWithType:@"get"];

        [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeXMPPServerUsers}];
        [stanza addChildWithName:@"archipel" andAttributes:{
            "action": TNArchipelTypeXMPPServerUsersList}];

        [[hypervisors objectAtIndex:i] sendStanza:stanza andRegisterSelector:@selector(_didGetXMPPUsers:) ofObject:self];
    }
}

/*! compute the answer containing the user' permissions
    @param aStanza TNStropheStanza containing the answer
*/
- (void)_didGetXMPPUsers:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var users = [aStanza childrenWithName:@"user"];

        for (var i = 0; i < [users count]; i++)
        {
            var user    = [users objectAtIndex:i],
                jid     = [TNStropheJID stropheJIDWithString:[user valueForAttribute:@"jid"]],
                type    = [user valueForAttribute:@"type"];

            if (type == @"human")
                [_datasourceUsers addXMPPUser:jid];
        }
        [_outlineViewUsers expandAll];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
    }
}


#pragma mark -
#pragma mark Delegate

- (void)outlineViewSelectionDidChange:(CPNotification)aNotification
{
    [self changeCurrentUser:nil];
}
@end
