import { Router } from "express";
import {
  listConversations,
  startPrivateConversation,
  createGroupOrCommunity,
  getConversationDetails,
  updateConversationSettings,
  updateSelfDestruct,
  updateModeration,
  updateClosedGroup,
  regenerateInviteLink,
  joinByInviteCode,
  joinGroupDirect,
  listMembers,
  promoteMember,
  demoteMember,
  kickMember,
  banMember,
  leaveGroup,
  transferOwnership,
  getAuditLog,
  getLeaderboard,
  listCommunityGroups,
  archiveConversation,
  unarchiveConversation,
  listArchivedConversations,
  uploadGroupPhoto,
  deleteConversation
} from "../controllers/chatController.js";
import { requireAuth } from "../middleware/auth.js";
import { upload } from "../config/upload.js";

const router = Router();

router.get("/", requireAuth, listConversations);
router.get("/archived", requireAuth, listArchivedConversations);
router.post("/private", requireAuth, startPrivateConversation);
router.post("/group", requireAuth, createGroupOrCommunity);
router.post("/join/:inviteCode", requireAuth, joinByInviteCode);
router.post("/:conversationId/join", requireAuth, joinGroupDirect);
router.get("/:communityId/groups", requireAuth, listCommunityGroups);
router.post("/:conversationId/archive", requireAuth, archiveConversation);
router.post("/:conversationId/unarchive", requireAuth, unarchiveConversation);
router.get("/:conversationId", requireAuth, getConversationDetails);
router.delete("/:conversationId", requireAuth, deleteConversation);
router.patch("/:conversationId/settings", requireAuth, updateConversationSettings);
router.post("/:conversationId/photo", requireAuth, upload.single("file"), uploadGroupPhoto);
router.patch("/:conversationId/self-destruct", requireAuth, updateSelfDestruct);
router.patch("/:conversationId/moderation", requireAuth, updateModeration);
router.patch("/:conversationId/closed", requireAuth, updateClosedGroup);
router.post("/:conversationId/invite/regenerate", requireAuth, regenerateInviteLink);
router.get("/:conversationId/members", requireAuth, listMembers);
router.post("/:conversationId/members/:memberId/promote", requireAuth, promoteMember);
router.post("/:conversationId/members/:memberId/demote", requireAuth, demoteMember);
router.post("/:conversationId/members/:memberId/kick", requireAuth, kickMember);
router.post("/:conversationId/members/:memberId/ban", requireAuth, banMember);
router.post("/:conversationId/leave", requireAuth, leaveGroup);
router.post("/:conversationId/transfer-ownership", requireAuth, transferOwnership);
router.get("/:conversationId/audit-log", requireAuth, getAuditLog);
router.get("/:conversationId/leaderboard", requireAuth, getLeaderboard);

export default router;
