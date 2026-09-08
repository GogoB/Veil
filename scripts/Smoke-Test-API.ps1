[CmdletBinding()]
param([string]$BaseURL = 'http://127.0.0.1:8080')

$ErrorActionPreference = 'Stop'
$suffix = ([Guid]::NewGuid().ToString('N')).Substring(0, 10)
$jsonHeaders = @{ 'Content-Type' = 'application/json' }

function Invoke-JsonPost([string]$Uri, [hashtable]$Headers, [hashtable]$Body) {
    Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -Body ($Body | ConvertTo-Json -Depth 12)
}

function Assert-HttpFailure([scriptblock]$Action, [int[]]$ExpectedStatus) {
    $succeeded = $false
    try {
        & $Action | Out-Null
        $succeeded = $true
    } catch {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }
        $actual = [int]$response.StatusCode
        if ($ExpectedStatus -notcontains $actual) {
            throw "Expected HTTP $($ExpectedStatus -join ' or '), received $actual."
        }
    }
    if ($succeeded) { throw "Request unexpectedly succeeded; expected HTTP $($ExpectedStatus -join ' or ')." }
}

$ready = Invoke-RestMethod -Method Get -Uri "$BaseURL/ready"
if ($ready.status -ne 'ready') { throw 'API readiness failed.' }

$aliceName = "alice_$suffix"
$alice = Invoke-JsonPost "$BaseURL/api/v1/accounts/create" $jsonHeaders @{
    username = $aliceName
    mode = 'recoverable'
    devicePublicKey = ('alice-device-' + ('x' * 48) + $suffix)
    securityPassphrase = 'local-smoke-passphrase'
}
if (-not $alice.sessionToken -or -not $alice.recoveryCode) { throw 'Recoverable account response omitted credentials.' }
$aliceHeaders = @{ Authorization = "Bearer $($alice.sessionToken)"; 'Content-Type' = 'application/json' }

$bobName = "bob_$suffix"
$bob = Invoke-JsonPost "$BaseURL/api/v1/accounts/create" $jsonHeaders @{
    username = $bobName
    mode = 'deviceOnly'
    devicePublicKey = ('bob-device-' + ('y' * 48) + $suffix)
}
if ($bob.recoveryCode) { throw 'Device-only account returned recovery material.' }
$bobHeaders = @{ Authorization = "Bearer $($bob.sessionToken)"; 'Content-Type' = 'application/json' }

Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/profiles/$($bob.profile.id)/follow" -Headers $aliceHeaders | Out-Null
$aliceProfile = Invoke-RestMethod -Method Patch -Uri "$BaseURL/api/v1/profiles/me" -Headers $aliceHeaders -Body (@{
    bio = 'Local smoke profile.'
} | ConvertTo-Json)
if ($aliceProfile.bio -ne 'Local smoke profile.' -or $aliceProfile.followingCount -ne 1) {
    throw 'Profile update or private follow-count bookkeeping failed.'
}

$attributed = Invoke-JsonPost "$BaseURL/api/v1/posts" $bobHeaders @{
    visibility = 'attributed'
    body = 'A public post for the chronological following feed.'
    mediaIDs = @()
    expiration = 'never'
    isSensitive = $false
    collaboratorProfileIDs = @()
}
$following = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/feeds/following" -Headers $aliceHeaders
if (-not ($following.items.id -contains $attributed.postID)) { throw 'Followed attributed post was absent from Following.' }

$pendingCollaboration = Invoke-JsonPost "$BaseURL/api/v1/posts" $aliceHeaders @{
    visibility = 'attributed'
    body = 'A post that waits for every collaborator before publication.'
    mediaIDs = @()
    expiration = 'never'
    isSensitive = $false
    collaboratorProfileIDs = @($bob.profile.id)
}
if ($pendingCollaboration.publicationState -ne 'pending' -or $pendingCollaboration.post) {
    throw 'Collaborative post was published before acceptance.'
}
$pendingDiscover = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/feeds/discover" -Headers $bobHeaders
if ($pendingDiscover.items.id -contains $pendingCollaboration.postID) {
    throw 'Pending collaborative post leaked into Discover.'
}
$invitations = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/collaborations/invitations" -Headers $bobHeaders
$invitation = $invitations | Where-Object { $_.postID -eq $pendingCollaboration.postID }
if (-not $invitation) { throw 'Collaboration invitation was not delivered.' }
Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/posts/$($pendingCollaboration.postID)/collaborators/$($bob.profile.id)/accept" -Headers $bobHeaders | Out-Null
$collaborationPost = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/posts/$($pendingCollaboration.postID)" -Headers $bobHeaders
if (@($collaborationPost.acceptedCollaborators).Count -ne 1) { throw 'Accepted collaborator was not shown on an attributed post.' }
Invoke-RestMethod -Method Delete -Uri "$BaseURL/api/v1/posts/$($pendingCollaboration.postID)/collaborators/me" -Headers $bobHeaders | Out-Null
$collaborationAfterLeave = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/posts/$($pendingCollaboration.postID)" -Headers $bobHeaders
if (@($collaborationAfterLeave.acceptedCollaborators).Count -ne 0) { throw 'Collaborator could not leave the post.' }

$anonymous = Invoke-JsonPost "$BaseURL/api/v1/posts" $aliceHeaders @{
    visibility = 'anonymous'
    anonymousMode = 'generatedAlias'
    body = 'Local smoke test: the city is listening.'
    mediaIDs = @()
    expiration = 'oneDay'
    isSensitive = $false
    collaboratorProfileIDs = @()
}
$discover = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/feeds/discover" -Headers $bobHeaders
if (-not ($discover.items.id -contains $anonymous.postID)) { throw 'Anonymous post was absent from Discover.' }
$anonymousJSON = $anonymous.post | ConvertTo-Json -Depth 12
if ($anonymousJSON -match '(?i)accountID|ownerID|matrix|recoveryCode|birthdate|ageBand') {
    throw 'Anonymous response leaked a restricted field.'
}

$imagePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'branding\veil-preview.png'
$uploadResponse = (& curl.exe --silent --show-error `
    -H "Authorization: Bearer $($alice.sessionToken)" `
    -F 'width=512' `
    -F 'height=512' `
    -F "file=@$imagePath;type=image/png" `
    --write-out "`nVEIL_HTTP_STATUS:%{http_code}" `
    "$BaseURL/api/v1/media/images") -join "`n"
if ($LASTEXITCODE -ne 0 -or $uploadResponse -notmatch '(?s)^(.*)\r?\nVEIL_HTTP_STATUS:(\d{3})$') {
    throw 'Image upload transport failed.'
}
$uploadJSON = $Matches[1]
if ([int]$Matches[2] -notin 200..299) { throw "Image upload failed: $uploadJSON" }
$uploadedMedia = $uploadJSON | ConvertFrom-Json
if (-not $uploadedMedia.id -or $uploadedMedia.width -gt 2400 -or $uploadedMedia.height -gt 2400) {
    throw 'Sanitized image upload returned invalid metadata.'
}
$imagePost = Invoke-JsonPost "$BaseURL/api/v1/posts" $aliceHeaders @{
    visibility = 'attributed'
    body = 'A sanitized local image upload.'
    mediaIDs = @($uploadedMedia.id)
    expiration = 'never'
    isSensitive = $false
    collaboratorProfileIDs = @()
}
if (@($imagePost.post.media).Count -ne 1) { throw 'Uploaded image was not attached to its post.' }

Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/posts/$($anonymous.postID)/likes" -Headers $bobHeaders | Out-Null
Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/posts/$($anonymous.postID)/likes" -Headers $bobHeaders | Out-Null
$likedPost = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/posts/$($anonymous.postID)" -Headers $bobHeaders
if ($likedPost.likeCount -ne 1) { throw 'Duplicate like changed the public count.' }

$comment = Invoke-JsonPost "$BaseURL/api/v1/posts/$($anonymous.postID)/comments" $bobHeaders @{
    body = 'A thread-scoped reply.'
    visibility = 'anonymous'
    anonymousMode = 'sigil'
}
if ($comment.actor.profile) { throw 'Anonymous comment exposed a profile.' }
if (-not $comment.isMine) { throw 'Comment ownership controls were absent for the creator.' }
Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/comments/$($comment.id)/likes" -Headers $aliceHeaders | Out-Null
Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/comments/$($comment.id)/likes" -Headers $aliceHeaders | Out-Null
$likedComments = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/posts/$($anonymous.postID)/comments" -Headers $aliceHeaders
$likedComment = $likedComments.items | Where-Object { $_.id -eq $comment.id }
if ($likedComment.likeCount -ne 1) { throw 'Duplicate comment like changed the public count.' }
Assert-HttpFailure -ExpectedStatus @(409) -Action {
    Invoke-JsonPost "$BaseURL/api/v1/posts/$($anonymous.postID)/comments" $bobHeaders @{
        body = 'Trying to switch identity in the same thread.'
        visibility = 'attributed'
    }
}
$reply = Invoke-JsonPost "$BaseURL/api/v1/posts/$($anonymous.postID)/comments" $aliceHeaders @{
    body = 'A reply from the hidden original poster.'
    parentID = $comment.id
    visibility = 'anonymous'
    anonymousMode = 'generatedAlias'
}
$flattenedReply = Invoke-JsonPost "$BaseURL/api/v1/posts/$($anonymous.postID)/comments" $aliceHeaders @{
    body = 'A deeper reply flattened under the visible root.'
    parentID = $reply.id
    visibility = 'anonymous'
    anonymousMode = 'generatedAlias'
}
if ($flattenedReply.parentID -ne $comment.id -or $flattenedReply.rootID -ne $comment.id) {
    throw 'Deep comment reply was not flattened below the root.'
}
$editedComment = Invoke-RestMethod -Method Patch -Uri "$BaseURL/api/v1/comments/$($comment.id)" -Headers $bobHeaders -Body (@{
    body = 'An edited thread-scoped reply.'
} | ConvertTo-Json)
if (-not $editedComment.editedAt) { throw 'Edited comment omitted its edit marker.' }
Invoke-RestMethod -Method Delete -Uri "$BaseURL/api/v1/comments/$($comment.id)" -Headers $bobHeaders | Out-Null
$commentsAfterDelete = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/posts/$($anonymous.postID)/comments" -Headers $aliceHeaders
$tombstone = $commentsAfterDelete.items | Where-Object { $_.id -eq $comment.id }
if (-not $tombstone.isDeleted -or $tombstone.body) { throw 'Deleted root comment did not become a tombstone.' }

$plainRepost = Invoke-JsonPost "$BaseURL/api/v1/posts" $aliceHeaders @{
    visibility = 'attributed'
    body = ''
    mediaIDs = @()
    expiration = 'never'
    isSensitive = $false
    collaboratorProfileIDs = @()
    referenceKind = 'repost'
    referencedPostID = $attributed.postID
}
$quotePost = Invoke-JsonPost "$BaseURL/api/v1/posts" $aliceHeaders @{
    visibility = 'attributed'
    body = 'This context remains after the original disappears.'
    mediaIDs = @()
    expiration = 'never'
    isSensitive = $false
    collaboratorProfileIDs = @()
    referenceKind = 'quote'
    referencedPostID = $attributed.postID
}
Invoke-RestMethod -Method Delete -Uri "$BaseURL/api/v1/posts/$($attributed.postID)" -Headers $bobHeaders | Out-Null
Assert-HttpFailure -ExpectedStatus @(404) -Action {
    Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/posts/$($plainRepost.postID)" -Headers $aliceHeaders
}
$quoteAfterOriginalDelete = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/posts/$($quotePost.postID)" -Headers $aliceHeaders
if (-not $quoteAfterOriginalDelete.reference.originalUnavailable -or $quoteAfterOriginalDelete.body -ne $quotePost.post.body) {
    throw 'Quote did not preserve its text and mark the missing original.'
}

Assert-HttpFailure -ExpectedStatus @(403) -Action {
    Invoke-JsonPost "$BaseURL/api/v1/conversations" $aliceHeaders @{
        targetProfileID = $bob.profile.id
        identity = 'anonymous'
        containsLink = $true
        containsMedia = $false
    }
}
$disabledPreferences = @{
    mutedProfileIDs = @()
    mutedTopicIDs = @()
    mutedKeywords = @()
    blurSensitiveMedia = $true
    anonymousRequestPolicy = 'disabled'
} | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$BaseURL/api/v1/preferences" -Headers $bobHeaders -Body $disabledPreferences | Out-Null
Assert-HttpFailure -ExpectedStatus @(403) -Action {
    Invoke-JsonPost "$BaseURL/api/v1/conversations" $aliceHeaders @{
        targetProfileID = $bob.profile.id
        identity = 'anonymous'
        containsLink = $false
        containsMedia = $false
    }
}
$allowPreferences = @{
    mutedProfileIDs = @()
    mutedTopicIDs = @()
    mutedKeywords = @()
    blurSensitiveMedia = $true
    anonymousRequestPolicy = 'allow'
} | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$BaseURL/api/v1/preferences" -Headers $bobHeaders -Body $allowPreferences | Out-Null
$allowedConversation = Invoke-JsonPost "$BaseURL/api/v1/conversations" $aliceHeaders @{
    targetProfileID = $bob.profile.id
    identity = 'anonymous'
    containsLink = $false
    containsMedia = $false
}
if (-not $allowedConversation.isAccepted) { throw 'Allowed anonymous message did not bypass the request inbox.' }
$filteredPreferences = @{
    mutedProfileIDs = @()
    mutedTopicIDs = @()
    mutedKeywords = @()
    blurSensitiveMedia = $true
    anonymousRequestPolicy = 'filtered'
} | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$BaseURL/api/v1/preferences" -Headers $bobHeaders -Body $filteredPreferences | Out-Null

$conversation = Invoke-JsonPost "$BaseURL/api/v1/conversations" $aliceHeaders @{
    targetProfileID = $bob.profile.id
    identity = 'anonymous'
    containsLink = $false
    containsMedia = $false
}
$bobConversations = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/conversations" -Headers $bobHeaders
$incomingRequest = $bobConversations | Where-Object { $_.id -eq $conversation.id }
if (-not $incomingRequest.isRequest) { throw 'Filtered anonymous message did not enter the recipient request inbox.' }
$room = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/conversations/$($conversation.id)/messaging-room" -Headers $aliceHeaders
if (-not $room.roomID) { throw 'Encrypted messaging room was not provisioned.' }

$eventID = '$smoke-' + $suffix + ':veil.local'
Invoke-JsonPost "$BaseURL/api/v1/conversations/$($conversation.id)/events" $aliceHeaders @{
    encryptedEventID = $eventID
    sentAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    containsLink = $false
    containsMedia = $false
} | Out-Null
Assert-HttpFailure -ExpectedStatus @(403) -Action {
    Invoke-JsonPost "$BaseURL/api/v1/conversations/$($conversation.id)/events" $aliceHeaders @{
        encryptedEventID = ('$second-' + $suffix + ':veil.local')
        sentAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        containsLink = $false
        containsMedia = $false
    }
}

$accepted = Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/conversations/$($conversation.id)/accept" -Headers $bobHeaders
if (-not $accepted.isAccepted) { throw 'Recipient could not accept the message request.' }
$settings = @{
    disappearingSeconds = 3600
    readReceiptsEnabled = $true
    typingIndicatorsEnabled = $false
} | ConvertTo-Json
$updatedConversation = Invoke-RestMethod -Method Put -Uri "$BaseURL/api/v1/conversations/$($conversation.id)/settings" -Headers $aliceHeaders -Body $settings
if ($updatedConversation.disappearingSeconds -ne 3600) { throw 'Conversation timer was not saved.' }
Invoke-RestMethod -Method Post -Uri "$BaseURL/api/v1/conversations/$($conversation.id)/block" -Headers $bobHeaders | Out-Null
$afterBlock = Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/conversations" -Headers $bobHeaders
if ($afterBlock.id -contains $conversation.id) { throw 'Blocked conversation remained in the inbox.' }

Assert-HttpFailure -ExpectedStatus @(401) -Action {
    Invoke-JsonPost "$BaseURL/api/v1/accounts/recover" $jsonHeaders @{
        username = $aliceName
        securityPassphrase = 'wrong-passphrase-value'
        recoveryCode = $alice.recoveryCode
        replacementDevicePublicKey = ('failed-device-' + ('z' * 48) + $suffix)
    }
}
$recovered = Invoke-JsonPost "$BaseURL/api/v1/accounts/recover" $jsonHeaders @{
    username = $aliceName
    securityPassphrase = 'local-smoke-passphrase'
    recoveryCode = $alice.recoveryCode
    replacementDevicePublicKey = ('replacement-device-' + ('r' * 48) + $suffix)
}
if (-not $recovered.recoveryCode -or $recovered.recoveryCode -eq $alice.recoveryCode) {
    throw 'Successful recovery did not rotate the recovery code.'
}
Assert-HttpFailure -ExpectedStatus @(401) -Action {
    Invoke-RestMethod -Method Get -Uri "$BaseURL/api/v1/accounts/me" -Headers $aliceHeaders
}

Write-Host "API smoke test passed: accounts, recovery, profiles, feeds, sanitized media, anonymous privacy, collaborations, reposts, quotes, comment controls, Matrix rooms, and message-request policy."
