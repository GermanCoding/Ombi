# Stage 1: Build Angular frontend
FROM node:20-bookworm-slim AS ui-build
WORKDIR /source
COPY Ombi/ClientApp/package.json Ombi/ClientApp/yarn.lock Ombi/ClientApp/
RUN yarn --cwd Ombi/ClientApp install --frozen-lockfile
COPY Ombi/ClientApp Ombi/ClientApp
RUN yarn --cwd Ombi/ClientApp run build

# Stage 2: Build and publish .NET backend
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG VERSION=4.0.0
WORKDIR /source

# Copy project files first to leverage layer caching for dotnet restore
COPY ["Ombi.sln", "."]
COPY ["Ombi/Ombi.csproj", "Ombi/"]
COPY ["Ombi.Api/Ombi.Api.csproj", "Ombi.Api/"]
COPY ["Ombi.Api.External/Ombi.Api.External.csproj", "Ombi.Api.External/"]
COPY ["Ombi.Core/Ombi.Core.csproj", "Ombi.Core/"]
COPY ["Ombi.DependencyInjection/Ombi.DependencyInjection.csproj", "Ombi.DependencyInjection/"]
COPY ["Ombi.HealthChecks/Ombi.HealthChecks.csproj", "Ombi.HealthChecks/"]
COPY ["Ombi.Helpers/Ombi.Helpers.csproj", "Ombi.Helpers/"]
COPY ["Ombi.Hubs/Ombi.Hubs.csproj", "Ombi.Hubs/"]
COPY ["Ombi.I18n/Ombi.I18n.csproj", "Ombi.I18n/"]
COPY ["Ombi.Mapping/Ombi.Mapping.csproj", "Ombi.Mapping/"]
COPY ["Ombi.Notifications/Ombi.Notifications.csproj", "Ombi.Notifications/"]
COPY ["Ombi.Notifications.Templates/Ombi.Notifications.Templates.csproj", "Ombi.Notifications.Templates/"]
COPY ["Ombi.Schedule/Ombi.Schedule.csproj", "Ombi.Schedule/"]
COPY ["Ombi.Settings/Ombi.Settings.csproj", "Ombi.Settings/"]
COPY ["Ombi.Store/Ombi.Store.csproj", "Ombi.Store/"]
RUN dotnet restore Ombi/Ombi.csproj

# Copy full source, then overlay the pre-built Angular dist so the
# PublishAngularDist MSBuild target picks it up during dotnet publish
COPY . .
COPY --from=ui-build /source/Ombi/ClientApp/dist Ombi/ClientApp/dist
RUN dotnet publish Ombi/Ombi.csproj -c Release --no-restore \
    -p:SemVer=${VERSION} -p:FullVer=${VERSION} \
    -o /app/publish

# Stage 3: Final runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

# Disable the .NET diagnostic pipe (prevents startup hangs in containers)
ENV COMPlus_EnableDiagnostics=0 \
    ASPNETCORE_URLS=http://+:5000

WORKDIR /app

# Create a non-root user for the application
RUN addgroup --system --gid 1000 ombi \
    && adduser --system --uid 1000 --ingroup ombi --no-create-home ombi \
    && mkdir -p /config \
    && chown ombi:ombi /config

COPY --from=build /app/publish .
RUN chown -R ombi:ombi /app

# Persist user data (databases, logs, config) outside the application directory
VOLUME /config

EXPOSE 5000

USER ombi

ENTRYPOINT ["dotnet", "Ombi.dll", "--storage", "/config"]
