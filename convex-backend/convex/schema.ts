import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

// Date reviews from the Open Date app. Only the summary and scores are stored,
// never the transcript or audio, which stay on the phone.
export default defineSchema({
  dateReviews: defineTable({
    deviceId: v.string(),
    matchName: v.string(),
    place: v.string(),
    rating: v.number(),
    agentScore: v.number(),
    summary: v.string(),
    next: v.string(),
    recorded: v.boolean(),
    createdAt: v.number(),
  }).index("by_device", ["deviceId"]),
});
