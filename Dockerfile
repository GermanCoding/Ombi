# Stage 1: Build Angular frontend
FROM node:20-slim AS ui-build
WORKDIR /source
COPY src/Ombi/ClientApp/package.json src/Ombi/ClientApp/yarn.lock src/Ombi/ClientApp/
RUN yarn --cwd src/Ombi/ClientApp install --frozen-lockfile
COPY src/Ombi/ClientApp src/Ombi/ClientApp
RUN yarn --cwd src/Ombi/ClientApp run build

# Stage 2: Build and publish .NET backend
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /source

# Copy project files first to leverage layer caching for dotnet restore
COPY ["src/Ombi.sln", "src/."]
COPY ["src/Ombi/Ombi.csproj", "src/Ombi/"]
COPY ["src/Ombi.Api/Ombi.Api.csproj", "src/Ombi.Api/"]
COPY ["src/Ombi.Api.External/Ombi.Api.External.csproj", "src/Ombi.Api.External/"]
COPY ["src/Ombi.Core/Ombi.Core.csproj", "src/Ombi.Core/"]
COPY ["src/Ombi.DependencyInjection/Ombi.DependencyInjection.csproj", "src/Ombi.DependencyInjection/"]
COPY ["src/Ombi.HealthChecks/Ombi.HealthChecks.csproj", "src/Ombi.HealthChecks/"]
COPY ["src/Ombi.Helpers/Ombi.Helpers.csproj", "src/Ombi.Helpers/"]
COPY ["src/Ombi.Hubs/Ombi.Hubs.csproj", "src/Ombi.Hubs/"]
COPY ["src/Ombi.I18n/Ombi.I18n.csproj", "src/Ombi.I18n/"]
COPY ["src/Ombi.Mapping/Ombi.Mapping.csproj", "src/Ombi.Mapping/"]
COPY ["src/Ombi.Notifications/Ombi.Notifications.csproj", "src/Ombi.Notifications/"]
COPY ["src/Ombi.Notifications.Templates/Ombi.Notifications.Templates.csproj", "src/Ombi.Notifications.Templates/"]
COPY ["src/Ombi.Schedule/Ombi.Schedule.csproj", "src/Ombi.Schedule/"]
COPY ["src/Ombi.Settings/Ombi.Settings.csproj", "src/Ombi.Settings/"]
COPY ["src/Ombi.Store/Ombi.Store.csproj", "src/Ombi.Store/"]
RUN dotnet restore src/Ombi/Ombi.csproj

# Copy full source, then overlay the pre-built Angular dist so the
# PublishAngularDist MSBuild target picks it up during dotnet publish
COPY . .
COPY --from=ui-build /source/src/Ombi/ClientApp/dist src/Ombi/ClientApp/dist
RUN dotnet publish src/Ombi/Ombi.csproj -c Release --no-restore \
    -o /app/publish

# Stage 3: Final runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime

# Disable the .NET diagnostic pipe (prevents startup hangs in containers)
ENV COMPlus_EnableDiagnostics=0 \
    ASPNETCORE_URLS=http://+:5000

WORKDIR /app

# UID/GID for the non-root ombi user (override at build time if needed)
ARG OMBI_UID=1000
ARG OMBI_GID=1000

# Create a non-root user for the application
RUN addgroup --system --gid ${OMBI_GID} ombi \
    && adduser --system --uid ${OMBI_UID} --ingroup ombi --no-create-home ombi \
    && mkdir -p /config \
    && chown ombi:ombi /config

COPY --from=build /app/publish .
RUN chown -R ombi:ombi /app

# Persist user data (databases, logs, config) outside the application directory
VOLUME /config

EXPOSE 5000

USER ombi

ENTRYPOINT ["dotnet", "Ombi.dll", "--storage", "/config"]
