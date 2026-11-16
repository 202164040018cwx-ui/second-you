import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const save = mutation({
  args: {
    deviceId: v.string(),
    matchName: v.string(),
    place: v.string(),
    rating: v.number(),
    agentScore: v.number(),
    summary: v.string(),
    next: v.string(),
    recorded: v.boolean(),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("dateReviews", { ...args, createdAt: Date.now() });
  },
});

export const history = query({
  args: { deviceId: v.string() },
  handler: async (ctx, { deviceId }) => {
    return await ctx.db
      .query("dateReviews")
      .withIndex("by_device", (q) => q.eq("deviceId", deviceId))
      .order("desc")
      .take(50);
  },
});
