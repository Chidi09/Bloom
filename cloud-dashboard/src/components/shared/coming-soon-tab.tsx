import * as React from "react";
import { Sparkle } from "@phosphor-icons/react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

interface ComingSoonTabProps {
  title: string;
  description: string;
  plannedFeatures?: string[];
}

export function ComingSoonTab({
  title,
  description,
  plannedFeatures,
}: ComingSoonTabProps) {
  return (
    <Card className="border-border/80 bg-card">
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle className="text-base">{title}</CardTitle>
          <Badge variant="secondary" className="font-mono text-[10px] gap-1 bg-primary/10 text-primary border-primary/20">
            <Sparkle className="size-3" weight="fill" />
            <span>Coming Soon</span>
          </Badge>
        </div>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      {plannedFeatures && plannedFeatures.length > 0 && (
        <CardContent className="space-y-3 pt-0">
          <p className="text-xs font-semibold text-foreground">Planned Capabilities:</p>
          <ul className="grid grid-cols-1 gap-2 text-xs text-muted-foreground sm:grid-cols-2">
            {plannedFeatures.map((feat) => (
              <li key={feat} className="flex items-center gap-2 rounded border border-border/60 bg-muted/20 p-2.5">
                <span className="size-1.5 rounded-full bg-primary" />
                <span>{feat}</span>
              </li>
            ))}
          </ul>
        </CardContent>
      )}
    </Card>
  );
}
