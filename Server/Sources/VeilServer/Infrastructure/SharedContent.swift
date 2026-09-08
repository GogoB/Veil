import Vapor
import VeilShared

extension VeilShared.AccountCreateRequest: @retroactive Content {}
extension VeilShared.AccountRecoveryRequest: @retroactive Content {}
extension VeilShared.SessionEnvelope: @retroactive Content {}
extension VeilShared.MessagingSessionConfiguration: @retroactive Content {}
extension VeilShared.MessagingRoomConfiguration: @retroactive Content {}
extension VeilShared.ProfileUpdateRequest: @retroactive Content {}
extension VeilShared.Profile: @retroactive Content {}
extension VeilShared.ProfileSummary: @retroactive Content {}
extension VeilShared.Topic: @retroactive Content {}
extension VeilShared.PostCreateRequest: @retroactive Content {}
extension VeilShared.PostEditRequest: @retroactive Content {}
extension VeilShared.PostCreationEnvelope: @retroactive Content {}
extension VeilShared.CollaborationInvitation: @retroactive Content {}
extension VeilShared.SearchResults: @retroactive Content {}
extension VeilShared.VeiledActivity: @retroactive Content {}
extension VeilShared.Post: @retroactive Content {}
extension VeilShared.CommentCreateRequest: @retroactive Content {}
extension VeilShared.CommentEditRequest: @retroactive Content {}
extension VeilShared.Comment: @retroactive Content {}
extension VeilShared.ConversationRequest: @retroactive Content {}
extension VeilShared.EncryptedEventRequest: @retroactive Content {}
extension VeilShared.ConversationSettingsRequest: @retroactive Content {}
extension VeilShared.Conversation: @retroactive Content {}
extension VeilShared.Message: @retroactive Content {}
extension VeilShared.ReportRequest: @retroactive Content {}
extension VeilShared.SelectedMessageReportRequest: @retroactive Content {}
extension VeilShared.ReportReceipt: @retroactive Content {}
extension VeilShared.ModeratorCase: @retroactive Content {}
extension VeilShared.Media: @retroactive Content {}
extension VeilShared.Health: @retroactive Content {}
extension VeilShared.ContentPreferences: @retroactive Content {}
extension VeilShared.Page: @retroactive Content {}
