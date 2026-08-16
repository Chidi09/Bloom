"use client";

import * as React from "react";
import { useParams } from "next/navigation";
import {
  Star,
  DownloadSimple,
  ArrowsClockwise,
  ChatCircleText,
  Flag,
  ArrowBendDownRight,
  CreditCard,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { ProviderIcon } from "@/components/status/provider-icon";
import { PlatformIcon } from "@/components/status/platform-icon";
import { PageHeader } from "@/components/shared/page-header";
import { api } from "@/lib/api/client";
import {
  TemplateDetailResponse,
  TemplateVersionResponse,
  ReviewResponse,
  PurchaseResponse,
} from "@/lib/schemas/marketplace";
import { useOrganizationStore } from "@/stores/organization-store";

export default function MarketplaceTemplateDetailPage() {
  const params = useParams<{ id: string }>();
  const templateId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  const [template, setTemplate] = React.useState<TemplateDetailResponse | null>(
    null,
  );
  const [reviews, setReviews] = React.useState<ReviewResponse[]>([]);
  const [selectedVersionId, setSelectedVersionId] = React.useState<string>("");
  const [activeVersionDetails, setActiveVersionDetails] =
    React.useState<TemplateVersionResponse | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Purchase state
  const [isPurchasing, setIsPurchasing] = React.useState(false);
  const [lastPurchaseResult, setLastPurchaseResult] =
    React.useState<PurchaseResponse | null>(null);

  // Review Dialog State
  const [writeReviewOpen, setWriteReviewOpen] = React.useState(false);
  const [reviewRating, setReviewRating] = React.useState<number>(5);
  const [reviewTitle, setReviewTitle] = React.useState("");
  const [reviewComment, setReviewComment] = React.useState("");
  const [isSubmittingReview, setIsSubmittingReview] = React.useState(false);

  // Report Dialog State
  const [reportReviewId, setReportReviewId] = React.useState<string | null>(
    null,
  );
  const [reportReason, setReportReason] = React.useState("misleading");
  const [reportDetails, setReportDetails] = React.useState("");
  const [isSubmittingReport, setIsSubmittingReport] = React.useState(false);

  // Author Reply State
  const [replyingReviewId, setReplyingReviewId] = React.useState<string | null>(
    null,
  );
  const [replyText, setReplyText] = React.useState("");
  const [isSubmittingReply, setIsSubmittingReply] = React.useState(false);

  const fetchTemplateData = React.useCallback(async () => {
    if (!templateId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [tmplRes, reviewsRes] = await Promise.all([
        api.get<TemplateDetailResponse>(`/marketplace/templates/${templateId}`),
        api.get<{ results: ReviewResponse[] }>(
          `/marketplace/templates/${templateId}/reviews`,
        ),
      ]);
      setTemplate(tmplRes);
      setReviews(reviewsRes?.results ?? []);
      if (tmplRes.versions?.length) {
        setSelectedVersionId(tmplRes.versions[0].id);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load template");
    } finally {
      setIsLoading(false);
    }
  }, [templateId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchTemplateData();
    };
    void run();
  }, [fetchTemplateData]);

  // Fetch full version details when selected version changes
  React.useEffect(() => {
    if (!templateId || !selectedVersionId) return;
    api
      .get<TemplateVersionResponse>(
        `/marketplace/templates/${templateId}/versions/${selectedVersionId}`,
      )
      .then((data) => {
        if (data) setActiveVersionDetails(data);
      })
      .catch(() => undefined);
  }, [templateId, selectedVersionId]);

  const handlePurchaseOrInstall = async () => {
    if (!template) return;
    setIsPurchasing(true);
    try {
      const res = await api.post<PurchaseResponse>(
        `/marketplace/templates/${template.id}/purchase`,
        {
          template_version_id: selectedVersionId || undefined,
        },
      );
      setLastPurchaseResult(res);
      if (res.status === "succeeded") {
        toast.success(`Template ${template.name} acquired successfully!`);
      } else {
        toast.info("Payment authorization session initiated.");
      }
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Purchase failed");
    } finally {
      setIsPurchasing(false);
    }
  };

  const handleWriteReview = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!template) return;
    setIsSubmittingReview(true);
    try {
      await api.post(`/marketplace/templates/${template.id}/reviews`, {
        rating: reviewRating,
        title: reviewTitle.trim() || undefined,
        comment: reviewComment.trim() || undefined,
      });
      toast.success("Review submitted for publication");
      setWriteReviewOpen(false);
      setReviewTitle("");
      setReviewComment("");
      setReviewRating(5);
      void fetchTemplateData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to submit review",
      );
    } finally {
      setIsSubmittingReview(false);
    }
  };

  const handleReportReview = async () => {
    if (!reportReviewId) return;
    setIsSubmittingReport(true);
    try {
      await api.post(`/marketplace/reviews/${reportReviewId}/report`, {
        reason: reportReason,
        details: reportDetails.trim() || undefined,
      });
      toast.success("Report submitted to moderation staff");
      setReportReviewId(null);
      setReportDetails("");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to submit report",
      );
    } finally {
      setIsSubmittingReport(false);
    }
  };

  const handleReplyReview = async (reviewId: string) => {
    if (!replyText.trim()) return;
    setIsSubmittingReply(true);
    try {
      await api.post(`/marketplace/reviews/${reviewId}/reply`, {
        response: replyText.trim(),
      });
      toast.success("Author response published");
      setReplyingReviewId(null);
      setReplyText("");
      void fetchTemplateData();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to post reply");
    } finally {
      setIsSubmittingReply(false);
    }
  };

  if (isLoading && !template) {
    return (
      <div className="mx-auto flex max-w-6xl items-center justify-center py-20">
        <BloomSpinner size={32} label="Loading template details..." />
      </div>
    );
  }

  if (error || !template) {
    return (
      <div className="mx-auto max-w-6xl space-y-4">
        <Alert variant="destructive">
          <AlertTitle>Error loading template</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error || "Template not found"}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchTemplateData()}
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  const isAuthor = template.organization_id === currentOrganizationId;
  const iconProvider =
    (template.metadata as { icon_provider?: string })?.icon_provider ||
    "flutter";
  const platforms = (template.metadata as { platforms?: string[] })
    ?.platforms || ["ios", "android", "web"];
  const tags = (template.metadata as { tags?: string[] })?.tags || [];
  const stars = (template.rating_bayesian_milli / 1000).toFixed(1);

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[
          { label: "Marketplace", href: "/marketplace" },
          { label: template.name },
        ]}
        title={template.name}
        description={template.slug}
        badge={
          template.is_free ? (
            <Badge
              variant="outline"
              className="border-emerald-500/40 bg-emerald-500/10 font-mono text-[11px] font-bold text-emerald-400"
            >
              FREE
            </Badge>
          ) : (
            <Badge className="border border-zinc-700 bg-zinc-800 font-mono text-xs font-bold text-zinc-100">
              ${(template.price_amount / 100).toFixed(2)}{" "}
              {template.price_currency.toUpperCase()}
            </Badge>
          )
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchTemplateData()}
              className="h-8 gap-1.5"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>
          </div>
        }
      />

      {/* Payment authorization status banner if returned */}
      {lastPurchaseResult?.client_secret && (
        <Card className="border-amber-500/40 bg-amber-950/20 p-4">
          <div className="flex items-start gap-3">
            <CreditCard className="mt-0.5 size-5 shrink-0 text-amber-400" />
            <div className="space-y-1">
              <h4 className="text-sm font-semibold text-zinc-100">
                Payment authorization required
              </h4>
              <p className="text-xs text-zinc-300">
                A client secret was issued by the backend:{" "}
                <code className="rounded bg-black px-1.5 py-0.5 font-mono text-[11px] text-amber-300">
                  {lastPurchaseResult.client_secret}
                </code>
                .
              </p>
              <p className="text-[11px] text-zinc-500">
                Upon Stripe webhook reconciliation, the purchase entitlement
                flips to succeeded.
              </p>
            </div>
          </div>
        </Card>
      )}

      {/* Main Template Overview Card */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Left 2 Cols: Description, Readme, Versions */}
        <div className="space-y-6 lg:col-span-2">
          <Card className="border-zinc-800 bg-[#09090b]">
            <CardHeader className="space-y-3 pb-4">
              <div className="flex items-center gap-3">
                <div className="flex size-12 shrink-0 items-center justify-center rounded-lg border border-zinc-800 bg-zinc-950 p-2.5">
                  <ProviderIcon provider={iconProvider} size="lg" />
                </div>
                <div>
                  <CardTitle className="text-base font-bold text-zinc-100">
                    {template.name}
                  </CardTitle>
                  <p className="text-xs text-zinc-400">
                    Published by Organization:{" "}
                    <span className="font-mono text-zinc-200">
                      {template.organization_id}
                    </span>
                  </p>
                </div>
              </div>

              <CardDescription className="text-xs leading-relaxed text-zinc-300">
                {template.description}
              </CardDescription>

              {tags.length > 0 && (
                <div className="flex flex-wrap gap-1.5 pt-1">
                  {tags.map((tag) => (
                    <Badge
                      key={tag}
                      variant="secondary"
                      className="font-mono text-[10px]"
                    >
                      #{tag}
                    </Badge>
                  ))}
                </div>
              )}
            </CardHeader>

            {/* Readme and Documentation */}
            <CardContent className="space-y-3 border-t border-zinc-800/80 pt-4">
              <h3 className="text-xs font-semibold tracking-wider text-zinc-400 uppercase">
                Documentation & Release Notes
              </h3>

              {activeVersionDetails?.readme ? (
                <pre className="max-h-72 overflow-y-auto rounded border border-zinc-800 bg-black p-4 font-mono text-xs leading-relaxed whitespace-pre-wrap text-zinc-300">
                  {activeVersionDetails.readme}
                </pre>
              ) : (
                <p className="text-xs text-zinc-500 italic">
                  No README provided for this version.
                </p>
              )}

              {activeVersionDetails?.changelog && (
                <div className="space-y-1 rounded border border-zinc-800/80 bg-zinc-950 p-3">
                  <span className="text-[11px] font-semibold text-zinc-400">
                    Changelog
                  </span>
                  <p className="font-mono text-xs text-zinc-300">
                    {activeVersionDetails.changelog}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Reviews Tabs */}
          <Tabs defaultValue="reviews" className="w-full space-y-4">
            <div className="flex items-center justify-between">
              <TabsList className="border border-zinc-800 bg-zinc-900/60 p-1">
                <TabsTrigger value="reviews" className="text-xs">
                  Buyer Reviews ({reviews.length})
                </TabsTrigger>
              </TabsList>

              <Button
                size="sm"
                variant="outline"
                onClick={() => setWriteReviewOpen(true)}
                className="h-8 gap-1.5 text-xs"
              >
                <ChatCircleText className="size-3.5" />
                <span>Write a Review</span>
              </Button>
            </div>

            <TabsContent value="reviews" className="space-y-4">
              {reviews.length === 0 ? (
                <div className="rounded-lg border border-zinc-800 bg-[#09090b] p-6 text-center text-xs text-zinc-500">
                  No reviews submitted yet. Be the first to review this
                  template!
                </div>
              ) : (
                <div className="space-y-3">
                  {reviews.map((rev) => {
                    const isReplying = replyingReviewId === rev.id;

                    return (
                      <Card
                        key={rev.id}
                        className="space-y-3 border-zinc-800 bg-[#09090b] p-4"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="space-y-1">
                            <div className="flex items-center gap-2">
                              <div className="flex items-center gap-0.5 text-amber-400">
                                {Array.from({ length: rev.rating }).map(
                                  (_, i) => (
                                    <Star
                                      key={i}
                                      className="size-3 fill-amber-400"
                                      weight="fill"
                                    />
                                  ),
                                )}
                              </div>
                              <h4 className="text-xs font-bold text-zinc-100">
                                {rev.title}
                              </h4>
                            </div>
                            <p className="text-xs leading-relaxed text-zinc-300">
                              {rev.comment}
                            </p>
                          </div>

                          <div className="flex items-center gap-2 text-right">
                            <span className="font-mono text-[10px] text-zinc-500">
                              {new Date(rev.created_at).toLocaleDateString()}
                            </span>
                            {!isAuthor && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setReportReviewId(rev.id)}
                                className="h-6 px-1.5 text-[10px] text-zinc-500 hover:text-red-400"
                              >
                                <Flag className="size-3" />
                              </Button>
                            )}
                          </div>
                        </div>

                        {/* Author response if present */}
                        {rev.author_response && (
                          <div className="space-y-1 rounded border border-zinc-800 bg-zinc-950 p-3 text-xs">
                            <div className="flex items-center gap-1.5 font-semibold text-[#FF4B8B]">
                              <ArrowBendDownRight className="size-3.5" />
                              <span>Author Response</span>
                              {rev.author_responded_at && (
                                <span className="font-mono text-[10px] font-normal text-zinc-500">
                                  (
                                  {new Date(
                                    rev.author_responded_at,
                                  ).toLocaleDateString()}
                                  )
                                </span>
                              )}
                            </div>
                            <p className="pl-5 text-zinc-300">
                              {rev.author_response}
                            </p>
                          </div>
                        )}

                        {/* Author inline reply affordance if template author */}
                        {isAuthor && !rev.author_response && (
                          <div className="pt-1">
                            {isReplying ? (
                              <div className="space-y-2 rounded border border-zinc-800 bg-zinc-950 p-3">
                                <Label className="text-xs font-semibold text-zinc-300">
                                  Reply as Author
                                </Label>
                                <Textarea
                                  placeholder="Write a response to this review..."
                                  value={replyText}
                                  onChange={(e) => setReplyText(e.target.value)}
                                  rows={2}
                                  className="text-xs"
                                />
                                <div className="flex items-center justify-end gap-2">
                                  <Button
                                    variant="outline"
                                    size="sm"
                                    onClick={() => setReplyingReviewId(null)}
                                    className="h-7 text-xs"
                                  >
                                    Cancel
                                  </Button>
                                  <Button
                                    size="sm"
                                    onClick={() =>
                                      void handleReplyReview(rev.id)
                                    }
                                    disabled={
                                      isSubmittingReply || !replyText.trim()
                                    }
                                    className="h-7 text-xs"
                                  >
                                    {isSubmittingReply ? (
                                      <BloomSpinner size={12} speed="fast" />
                                    ) : null}
                                    Post Reply
                                  </Button>
                                </div>
                              </div>
                            ) : (
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => {
                                  setReplyingReviewId(rev.id);
                                  setReplyText("");
                                }}
                                className="h-7 text-xs text-zinc-300"
                              >
                                Reply to Review
                              </Button>
                            )}
                          </div>
                        )}
                      </Card>
                    );
                  })}
                </div>
              )}
            </TabsContent>
          </Tabs>
        </div>

        {/* Right 1 Col: Purchase Card & Version Selector */}
        <div className="space-y-5">
          <Card className="sticky top-6 border-zinc-800 bg-[#09090b]">
            <CardHeader className="space-y-2 pb-3">
              <div className="flex items-baseline justify-between font-mono">
                <span className="text-2xl font-black text-zinc-100">
                  {template.is_free
                    ? "Free"
                    : `$${(template.price_amount / 100).toFixed(2)}`}
                </span>
                <span className="text-xs text-zinc-400 uppercase">
                  {template.price_currency}
                </span>
              </div>
              <p className="text-xs text-zinc-400">
                Instant license to scaffold, build, and deploy in any
                organization project.
              </p>
            </CardHeader>

            <CardContent className="space-y-4">
              {/* Version Selector */}
              <div className="space-y-1.5">
                <Label htmlFor="ver-select" className="text-xs text-zinc-300">
                  Release Version
                </Label>
                <Select
                  value={selectedVersionId}
                  onValueChange={(v) => v && setSelectedVersionId(v)}
                >
                  <SelectTrigger id="ver-select" className="font-mono text-xs">
                    <SelectValue placeholder="Select version" />
                  </SelectTrigger>
                  <SelectContent>
                    {template.versions.map((v) => (
                      <SelectItem
                        key={v.id}
                        value={v.id}
                        className="font-mono text-xs"
                      >
                        v{v.version} ({v.install_count} installs)
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Stats Breakdown */}
              <div className="space-y-2 rounded-lg border border-zinc-800/80 bg-zinc-950 p-3 font-mono text-xs">
                <div className="flex justify-between">
                  <span className="text-zinc-500">Average Rating</span>
                  <span className="font-bold text-amber-400">
                    {stars} ★ ({template.rating_count})
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-500">Total Installs</span>
                  <span className="text-zinc-200">
                    {template.install_count.toLocaleString()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-500">Platforms</span>
                  <div className="flex gap-1">
                    {platforms.map((p) => (
                      <PlatformIcon key={p} platform={p} size="sm" />
                    ))}
                  </div>
                </div>
              </div>

              {/* Purchase/Install Action Button */}
              <Button
                size="lg"
                disabled={isPurchasing}
                onClick={() => void handlePurchaseOrInstall()}
                className="h-10 w-full bg-[#FF4B8B] text-xs font-semibold text-white hover:bg-[#FF4B8B]/90"
              >
                {isPurchasing ? (
                  <BloomSpinner size={16} speed="fast" className="mr-2" />
                ) : (
                  <DownloadSimple className="mr-2 size-4" weight="bold" />
                )}
                {template.is_free
                  ? "Install Template"
                  : `Purchase for $${(template.price_amount / 100).toFixed(0)}`}
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Write Review Dialog */}
      <Dialog open={writeReviewOpen} onOpenChange={setWriteReviewOpen}>
        <DialogContent className="border-zinc-800 bg-zinc-950 text-zinc-100 sm:max-w-md">
          <form onSubmit={handleWriteReview}>
            <DialogHeader>
              <DialogTitle>Write a Review</DialogTitle>
              <DialogDescription>
                Share your experience using &quot;{template.name}&quot; with
                other developers.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="space-y-1.5">
                <Label className="text-xs text-zinc-300">Rating (Stars)</Label>
                <div className="flex items-center gap-2">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      type="button"
                      key={star}
                      onClick={() => setReviewRating(star)}
                      className="cursor-pointer p-1 text-zinc-500 transition-colors hover:text-amber-400"
                    >
                      <Star
                        className={`size-6 ${
                          star <= reviewRating
                            ? "fill-amber-400 text-amber-400"
                            : "text-zinc-600"
                        }`}
                        weight={star <= reviewRating ? "fill" : "regular"}
                      />
                    </button>
                  ))}
                  <span className="ml-2 font-mono text-xs font-bold text-amber-400">
                    {reviewRating} of 5
                  </span>
                </div>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="rev-title" className="text-xs text-zinc-300">
                  Headline / Title
                </Label>
                <Input
                  id="rev-title"
                  placeholder="e.g. Clean architecture, easy setup"
                  value={reviewTitle}
                  onChange={(e) => setReviewTitle(e.target.value)}
                  className="text-xs"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="rev-comment" className="text-xs text-zinc-300">
                  Review Comments
                </Label>
                <Textarea
                  id="rev-comment"
                  placeholder="Provide details on codebase quality, dependencies, or usability..."
                  value={reviewComment}
                  onChange={(e) => setReviewComment(e.target.value)}
                  rows={3}
                  className="text-xs"
                />
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setWriteReviewOpen(false)}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={isSubmittingReview}>
                {isSubmittingReview ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Publish Review
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Report Review Dialog */}
      <Dialog
        open={reportReviewId !== null}
        onOpenChange={(open) => !open && setReportReviewId(null)}
      >
        <DialogContent className="border-zinc-800 bg-zinc-950 text-zinc-100 sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Report Review</DialogTitle>
            <DialogDescription>
              Flag this review for staff moderation review.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-3">
            <div className="space-y-1.5">
              <Label htmlFor="rep-reason">Reason Category</Label>
              <Select
                value={reportReason}
                onValueChange={(v) => v && setReportReason(v)}
              >
                <SelectTrigger id="rep-reason" className="text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="spam" className="text-xs">
                    Spam / Advertising
                  </SelectItem>
                  <SelectItem value="harassment" className="text-xs">
                    Harassment / Abusive language
                  </SelectItem>
                  <SelectItem value="misleading" className="text-xs">
                    Misleading or false claims
                  </SelectItem>
                  <SelectItem value="inappropriate" className="text-xs">
                    Inappropriate content
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="rep-details">Additional Details (Optional)</Label>
              <Textarea
                id="rep-details"
                placeholder="Describe why this review violates marketplace guidelines..."
                value={reportDetails}
                onChange={(e) => setReportDetails(e.target.value)}
                rows={3}
                className="text-xs"
              />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setReportReviewId(null)}>
              Cancel
            </Button>
            <Button
              onClick={() => void handleReportReview()}
              disabled={isSubmittingReport}
            >
              {isSubmittingReport ? (
                <BloomSpinner size={14} speed="fast" className="mr-2" />
              ) : null}
              Submit Report
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
